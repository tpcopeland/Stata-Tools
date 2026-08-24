*! test_pygrid.do Version 1.0.0  2026/08/12
*! Functional and error-path tests for pygrid
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "test_pygrid.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local d2010 = td(01jan2010)
local e2010 = td(31dec2010)
local d2012 = td(01jan2012)
local e2012 = td(31dec2012)

**# Core axes and options

**## Calendar defaults and stored contract
capture noisily {
    _pygrid_make_calendar, n(2) start(`=td(01jan2010)') end(`=td(31dec2012)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    assert _N == 6
    assert period[1] == 2010 & period[3] == 2012
    assert r(N_persons) == 2
    assert r(N_rows) == 6
    assert r(N_empty_window) == 0
    assert r(N_uncovered) == 0
    assert r(N_partial) == 0
    assert !missing(r(pytotal))
    assert reldif(r(pytotal), 2 * 1096 / 365.25) < 1e-12
    assert !missing(r(pymin))
    assert reldif(r(pymin), 365 / 365.25) < 1e-12
    assert !missing(r(pymax))
    assert reldif(r(pymax), 366 / 365.25) < 1e-12
    assert r(period_min) == 2010
    assert r(period_max) == 2012
    assert "`r(axis)'" == "calendar"
    assert "`r(width)'" == "1"
    assert "`r(unit)'" == "year"
    assert "`r(pyconvention)'" == "inclusive"
    local stamp : char _dta[pygrid_version]
    assert "`stamp'" == "1.0.0"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("calendar defaults and stored contract") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## if and in select source episodes
capture noisily {
    _pygrid_make_calendar, n(5) start(`=td(01jan2010)') end(`=td(31dec2010)')
    pygrid if mod(id, 2) == 1 in 2/5, id(id) start(window_start) ///
        end(window_end) axis(calendar)
    assert _N == 2
    assert id[1] == 3 & id[2] == 5
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("if and in qualifiers") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Calendar month blocks are January anchored
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(15feb2010)') end(`=td(20jun2010)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        unit(month) width(2) partial(flag)
    assert _N == 3
    assert period[1] == ym(2010, 1)
    assert period[2] == ym(2010, 3)
    assert period_start[1] == td(15feb2010)
    assert period_stop[3] == td(20jun2010)
    assert _partial[1] == 1 & _partial[2] == 0 & _partial[3] == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("calendar month blocks and partial flag") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Calendar day blocks and period filters
capture noisily {
    _pygrid_make_calendar, n(1) start(0) end(20)
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        unit(day) width(7) first(7) last(14)
    assert _N == 2
    assert period[1] == 7 & period[2] == 14
    assert period_start[1] == 7 & period_stop[2] == 20
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("calendar day width and first/last") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Anniversary keep and relative numbering
capture noisily {
    clear
    set obs 1
    generate long id = 1
    generate double origin = td(01jan2010)
    generate double followup = td(15apr2013)
    pygrid, id(id) start(origin) end(followup) axis(anniversary) ///
        origin(origin) keep(origin)
    assert _N == 4
    assert period[1] == 1 & period[4] == 4
    assert rel_period[1] == 0 & rel_period[4] == 3
    assert period_start[1] == td(01jan2010)
    assert period_stop[1] == floor(td(01jan2010) + 365.25) - 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("anniversary numbering") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Anniversary inversion is exact on a floored nominal boundary
capture noisily {
    clear
    set obs 1
    generate long id = 1
    generate double origin = td(01jan2010)
    generate double boundary = floor(origin + 365.25)
    local boundary_value = boundary[1]
    pygrid, id(id) start(boundary) end(boundary) axis(anniversary) ///
        origin(origin) generate(pno) relgen(relative) ///
        startgen(pstart) stopgen(pstop) pytime(pdays) pyunit(day) noisily
    assert _N == 1
    assert pno == 2 & relative == 1
    assert pstart == `boundary_value' & pstop == `boundary_value'
    assert pdays == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("anniversary exact nominal boundary") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Anniversary partial drop
capture noisily {
    clear
    set obs 1
    generate long id = 1
    generate double origin = td(01jan2010)
    generate double followup = td(15apr2013)
    pygrid, id(id) start(origin) end(followup) axis(anniversary) ///
        origin(origin) partial(drop)
    assert _N == 3
    assert period[3] == 3
    assert r(N_partial) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("anniversary partial drop") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Fixed axis and exclusive convention
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(10jan2010)') end(`=td(10jan2010)')
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) ///
        pyunit(day) noinclusive
    assert _N == 1
    assert period == 1
    assert person_years == 0
    assert "`r(pyconvention)'" == "exclusive"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("fixed axis and noinclusive") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Clamp and row-specific coverage compose
capture noisily {
    clear
    input long id double(window_start window_end coverage_start)
        1 14976 17531 16618
        2 16071 17896 16436
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        clamp(15341 17531) coverage(coverage_start)
    assert _covered == 1
    assert period_start[1] == 16618
    assert r(N_uncovered) == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("clamp plus variable coverage") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Duplicate ids remain episode-specific
capture noisily {
    clear
    input long id double(window_start window_end)
        1 18263 18627
        1 18993 19358
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    assert _N == 2
    assert _pygrid_episode[1] != _pygrid_episode[2]
    assert r(N_persons) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("duplicate-id independent episodes") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## String identifiers
capture noisily {
    clear
    input str12 id double(window_start window_end)
        "person-a" 18263 18627
        "person-b" 18263 18627
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    assert _N == 2
    assert id[1] == "person-a"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("string identifiers") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Mutation and state contracts

**## saveas restores input while ordinary mode replaces it
capture noisily {
    tempfile saved original
    _pygrid_make_calendar, n(2) start(`=td(01jan2010)') end(`=td(31dec2011)')
    generate double marker = id * 10
    save `original'
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        keep(marker) saveas(`saved') replace
    cf _all using `original', all
    local spaced_path "pygrid saveas path with space.dta"
    capture erase "`spaced_path'"
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        saveas("`spaced_path'") replace
    confirm file "`spaced_path'"
    erase "`spaced_path'"
    use `saved', clear
    assert _N == 4
    assert marker[1] == 10
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("saveas preservation and payload") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Varabbrev restored on success and missing-bound failure
capture noisily {
    set varabbrev on
    _pygrid_make_calendar, n(1) start(`=td(01jan2010)') end(`=td(31dec2010)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    assert "`c(varabbrev)'" == "on"
    clear
    set obs 1
    generate id = 1
    generate double s = .a
    generate double e = td(01jan2010)
    capture noisily pygrid, id(id) start(s) end(e) axis(calendar)
    assert _rc == 416
    assert "`c(varabbrev)'" == "on"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("varabbrev restoration") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Error classes

**## Rule validation returns 198
capture noisily {
    _pygrid_make_calendar, n(1) start(1) end(10)
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(bad)
    assert _rc == 198
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(calendar) width(0)
    assert _rc == 198
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(calendar) unit(week)
    assert _rc == 198
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(calendar) partial(bad)
    assert _rc == 198
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(anniversary)
    assert _rc == 198
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(anniversary) origin(window_start) width(.1) unit(day)
    assert _rc == 198
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("invalid rules return 198") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Output collisions fail before mutation
capture noisily {
    tempfile before
    _pygrid_make_calendar, n(1) start(1) end(10)
    save `before'
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(fixed) generate(result) pytime(result)
    assert _rc == 198
    cf _all using `before', all
    generate double period = 7
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    assert _rc == 110
    assert period == 7
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("output collision guards") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Datetime input returns 109
capture noisily {
    clear
    set obs 1
    generate id = 1
    generate double s = clock("01jan2010 00:00", "DMY hm")
    generate double e = clock("02jan2010 00:00", "DMY hm")
    format s e %tc
    capture noisily pygrid, id(id) start(s) end(e) axis(fixed)
    assert _rc == 109
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("datetime rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Deep-review regressions

**## Full calendar and anniversary months remain valid
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(01jan2010)') end(`=td(31jan2010)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        unit(month) pytime(person_days) pyunit(day)
    assert _N == 1
    assert period_start == td(01jan2010) & period_stop == td(31jan2010)
    assert person_days == 31
    assert r(pytotal) == 31

    clear
    set obs 1
    generate long id = 1
    generate double origin = td(01jan2010)
    generate double followup = td(31dec2010)
    pygrid, id(id) start(origin) end(followup) axis(anniversary) ///
        origin(origin) unit(month) pytime(person_days) pyunit(day)
    assert _N == 12
    assert r(pytotal) == 365
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("full month width guard") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Numeric daily-date inputs must be integer valued
capture noisily {
    clear
    set obs 1
    generate long id = 1
    generate double s = 1.5
    generate double e = 3
    generate double origin = 1
    generate double coverage_start = 1
    capture noisily pygrid, id(id) start(s) end(e) axis(fixed)
    assert _rc == 459

    replace s = 1
    replace e = 3.5
    capture noisily pygrid, id(id) start(s) end(e) axis(fixed)
    assert _rc == 459

    replace e = 3
    replace origin = 1.5
    capture noisily pygrid, id(id) start(s) end(e) axis(anniversary) origin(origin)
    assert _rc == 459

    replace origin = 1
    replace coverage_start = 1.5
    capture noisily pygrid, id(id) start(s) end(e) axis(fixed) ///
        coverage(coverage_start)
    assert _rc == 459

    replace coverage_start = 1
    capture noisily pygrid, id(id) start(s) end(e) axis(fixed) clamp(1.5 3)
    assert _rc == 198
    capture noisily pygrid, id(id) start(s) end(e) axis(fixed) coverage(1.5)
    assert _rc == 198
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("integer daily-date contract") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Overlapping episodes for one identifier fail before mutation
capture noisily {
    tempfile before
    clear
    input long id double(window_start window_end)
        1 18263 18300
        1 18290 18320
    end
    save `before'
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(fixed) pyunit(day)
    assert _rc == 459
    cf _all using `before', all

    replace window_start = 1 in 1
    replace window_end = 2 in 1
    replace window_start = 2 in 2
    replace window_end = 3 in 2
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(fixed) pyunit(day)
    assert _rc == 459
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) ///
        noinclusive pyunit(day)
    assert _N == 2
    assert r(pytotal) == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("overlapping episode rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## strL identifiers are rejected before grid construction
capture noisily {
    clear
    set obs 1
    generate strL id = "person-a"
    generate double window_start = 1
    generate double window_end = 2
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(fixed) pyunit(day)
    assert _rc == 109
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("strL grid-identifier rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result test_pygrid `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
