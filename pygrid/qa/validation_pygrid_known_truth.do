*! validation_pygrid_known_truth.do Version 1.0.1  2026/08/30
*! Hand-computed person-time and partition validation for pygrid
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "validation_pygrid_known_truth.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

**# Hand-computed calendar cases

**## Full calendar years include 365, 365, and 366 days
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(01jan2010)') end(`=td(31dec2012)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    sort period
    assert _N == 3
    assert !missing(person_years[1])
    assert reldif(person_years[1], 365 / 365.25) < 1e-12
    assert !missing(person_years[2])
    assert reldif(person_years[2], 365 / 365.25) < 1e-12
    assert !missing(person_years[3])
    assert reldif(person_years[3], 366 / 365.25) < 1e-12
    assert !missing(r(pytotal))
    assert reldif(r(pytotal), 1096 / 365.25) < 1e-12
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("full calendar years") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Partial first and last years have hand-counted days
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(15jun2010)') end(`=td(20mar2012)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    sort period
    assert _N == 3
    assert !missing(person_years[1])
    assert reldif(person_years[1], 200 / 365.25) < 1e-12
    assert !missing(person_years[2])
    assert reldif(person_years[2], 365 / 365.25) < 1e-12
    assert !missing(person_years[3])
    assert reldif(person_years[3], 80 / 365.25) < 1e-12
    assert !missing(r(pytotal), (td(20mar2012) - td(15jun2010) + 1) / 365.25)
    assert reldif(r(pytotal), ///
        (td(20mar2012) - td(15jun2010) + 1) / 365.25) < 1e-12
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("partial calendar years") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Single-day inclusive and exclusive conventions
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(29feb2012)') end(`=td(29feb2012)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    assert !missing(person_years)
    assert reldif(person_years, 1 / 365.25) < 1e-12
    _pygrid_make_calendar, n(1) start(`=td(29feb2012)') end(`=td(29feb2012)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) noinclusive
    assert person_years == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("single-day inclusivity") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Leap day appears in exactly one row
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(28feb2012)') end(`=td(01mar2012)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) pyunit(day)
    assert _N == 1
    assert person_years == 3
    assert r(pytotal) == 3
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("leap-day exact count") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Window restrictions and anniversary truth

**## Anniversary fourth period is partial and drop removes it
capture noisily {
    clear
    set obs 1
    generate long id = 1
    generate double origin = td(01jan2010)
    generate double followup = td(15apr2013)
    pygrid, id(id) start(origin) end(followup) axis(anniversary) origin(origin)
    assert _N == 4
    assert period_start[4] == floor(td(01jan2010) + 3 * 365.25)
    assert period_stop[4] == td(15apr2013)
    local total = r(pytotal)
    assert !missing(`total', (td(15apr2013) - td(01jan2010) + 1) / 365.25)
    assert reldif(`total', (td(15apr2013) - td(01jan2010) + 1) / 365.25) < 1e-12
    clear
    set obs 1
    generate long id = 1
    generate double origin = td(01jan2010)
    generate double followup = td(15apr2013)
    pygrid, id(id) start(origin) end(followup) axis(anniversary) ///
        origin(origin) partial(drop)
    assert _N == 3
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("anniversary known boundaries") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Coverage starts 01jul2005 and contributes 184 days that year
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(01jan2001)') end(`=td(31dec2006)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        coverage(`=td(01jul2005)')
    sort period
    assert _N == 2
    assert period[1] == 2005
    assert !missing(person_years[1])
    assert reldif(person_years[1], 184 / 365.25) < 1e-12
    assert r(N_uncovered) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("coverage truncation known days") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Clamp and coverage bind opposite window sides
capture noisily {
    _pygrid_make_calendar, n(1) start(`=td(01jan2000)') end(`=td(31dec2010)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        clamp(`=td(01jan2004)' `=td(31dec2008)') coverage(`=td(01jul2005)')
    quietly summarize person_years, meanonly
    assert !missing(r(sum), (td(31dec2008) - td(01jul2005) + 1) / 365.25)
    assert reldif(r(sum), (td(31dec2008) - td(01jul2005) + 1) / 365.25) < 1e-12
    assert period_start[1] == td(01jul2005)
    assert period_stop[_N] == td(31dec2008)
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("clamp and coverage partition") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Restriction-induced empty windows are counted while malformed input errors
capture noisily {
    clear
    input long id double(window_start window_end coverage_start)
        1 10 20 30
        2 10 20 10
    end
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) ///
        pyunit(day) coverage(coverage_start)
    assert _N == 1 & id == 2
    assert r(N_empty_window) == 1
    clear
    input long id double(window_start window_end)
        1 10 9
        2 10 20
    end
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    assert _rc == 459
    clear
    input long id double(window_start window_end)
        1 10 .a
    end
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    assert _rc == 416
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("restricted, malformed, and missing windows") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Randomized partition and ordering invariants

**## Five hundred windows partition to 1e-9
capture noisily {
    set seed 481516
    clear
    set obs 500
    generate long id = _n
    generate double source_start = td(01jan1990) + floor(runiform() * 9000)
    generate double source_end = source_start + floor(runiform() * 2200)
    generate double expected = (source_end - source_start + 1) / 365.25
    tempfile expected_file
    preserve
    keep id expected
    save `expected_file'
    restore
    pygrid, id(id) start(source_start) end(source_end) axis(calendar)
    collapse (sum) observed=person_years, by(id)
    merge 1:1 id using `expected_file', assert(match) nogen
    assert abs(observed - expected) < 1e-9
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("500-window partition invariant") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Reversing input order leaves row values identical
capture noisily {
    set seed 8675309
    clear
    set obs 50
    generate long id = _n
    generate double source_start = td(01jan2000) + floor(runiform() * 3000)
    generate double source_end = source_start + floor(runiform() * 800)
    tempfile input forward
    save `input'
    pygrid, id(id) start(source_start) end(source_end) axis(calendar)
    sort id period
    save `forward'
    use `input', clear
    gsort -id
    pygrid, id(id) start(source_start) end(source_end) axis(calendar)
    sort id period
    cf id period period_start period_stop person_years using `forward', all
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("input order invariance") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result validation_pygrid_known_truth ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
