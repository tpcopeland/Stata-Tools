*! test_package_contracts.do Version 1.0.1  2026/08/30
*! Installed-user, characteristics, state, and help-source contracts
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "test_package_contracts.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local d2010 = td(01jan2010)
local e2010 = td(31dec2010)

**# Installed-user surface

**## Public commands and every helper autoload after discard
capture noisily {
    discard
    which pygrid
    which pyattach
    which _pygrid_window
    which _pygrid_expand
    which _pygrid_pytime
    which _pygrid_stamp
    which _pygrid_report
    which _pyattach_join
    _pygrid_make_calendar, n(1) start(1) end(10)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed)
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("installed helper autoload") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Saved grid characteristics survive round trip
capture noisily {
    tempfile grid events
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    save `grid'
    clear
    set obs 1
    generate long id = 1
    generate double event_date = `d2010'
    save `events'
    use `grid', clear
    local before : char _dta[pygrid_start]
    local pyunit_before : char _dta[pygrid_pyunit]
    local episode_before : char _dta[pygrid_episode]
    local contract_before : char _dta[pygrid_contract]
    local signature_before : char _dta[pygrid_signature]
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    local after : char _dta[pygrid_start]
    local pyunit_after : char _dta[pygrid_pyunit]
    local contract_after : char _dta[pygrid_contract]
    local signature_after : char _dta[pygrid_signature]
    assert "`before'" == "period_start"
    assert "`after'" == "period_start"
    assert "`pyunit_before'" == "year" & "`pyunit_after'" == "year"
    assert "`episode_before'" == "_pygrid_episode"
    assert `"`contract_before'"' != "" & `"`contract_after'"' == `"`contract_before'"'
    assert `"`signature_before'"' != "" & `"`signature_after'"' == `"`signature_before'"'
    assert n == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("saved-grid round trip") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Corrupt grid characteristics are rejected before attachment
capture noisily {
    tempfile events before
    clear
    set obs 1
    generate long id = 1
    generate double event_date = `d2010'
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    char _dta[pygrid_axis] "nearest"
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) count(n)
    assert _rc == 459
    _pygrid_assert_data_equal using `before', order
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    replace person_years = .
    save `before', replace
    capture noisily pyattach using `events', id(id) date(event_date) count(n)
    assert _rc == 459
    _pygrid_assert_data_equal using `before', order
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("corrupt grid stamp rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Mid-build failure restores original data
capture noisily {
    tempfile before
    _pygrid_make_calendar, n(1) start(1) end(20)
    generate marker = 99
    save `before'
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(calendar) unit(day) width(7) first(100)
    assert _rc == 2000
    _pygrid_assert_data_equal using `before', order
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("mid-build rollback") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## pyattach failure leaves earlier attached columns unchanged
capture noisily {
    tempfile good bad before
    clear
    set obs 1
    generate long id = 1
    generate double event_date = 1
    save `good'
    replace event_date = 100
    save `bad'
    _pygrid_make_calendar, n(1) start(1) end(10)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    pyattach using `good', id(id) date(event_date) count(good_n) orphans(report)
    save `before'
    capture noisily pyattach using `bad', id(id) date(event_date) count(bad_n)
    assert _rc == 459
    _pygrid_assert_data_equal using `before', order
    assert good_n == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("attach rollback preserves prior columns") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Distribution metadata

**## Package lists every shipped runtime file
capture noisily {
    local shipped "pygrid.ado pyattach.ado _pygrid_window.ado _pygrid_expand.ado _pygrid_pytime.ado _pygrid_stamp.ado _pygrid_report.ado _pyattach_join.ado pygrid.sthlp pyattach.sthlp"
    tempname fh
    file open `fh' using "`pkg_dir'/pygrid.pkg", read text
    local pkg_text ""
    file read `fh' line
    while r(eof) == 0 {
        local pkg_text `"`pkg_text' `line'"'
        file read `fh' line
    }
    file close `fh'
    foreach f of local shipped {
        assert strpos(`"`pkg_text'"', "f `f'") > 0
        confirm file "`pkg_dir'/`f'"
    }
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("package file completeness") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Help source has one flagship version and required conceptual sections
capture noisily {
    tempname fh
    file open `fh' using "`pkg_dir'/pygrid.sthlp", read text
    local grid_help ""
    file read `fh' line
    while r(eof) == 0 {
        local grid_help `"`grid_help' `line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`grid_help'"', "Person-time conventions") > 0
    assert strpos(`"`grid_help'"', "Denominators and zero filling") > 0
    assert strpos(`"`grid_help'"', "stsplit") > 0
    file open `fh' using "`pkg_dir'/pyattach.sthlp", read text
    local attach_help ""
    file read `fh' line
    while r(eof) == 0 {
        local attach_help `"`attach_help' `line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`attach_help'"', "*! version") == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("help conceptual and version contracts") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Help files render cleanly through Stata's SMCL interpreter
capture noisily {
    tempfile broken_base
    local broken "`broken_base'.sthlp"
    tempname fh
    file open `fh' using "`broken'", write replace text
    file write `fh' "{smcl}" _n
    file write `fh' "{title:Render probe}" _n _n
    file write `fh' "{pstd}" _n
    file write `fh' "A directive split across a source newline: {bf:broken" _n
    file write `fh' "directive} renders as literal markup." _n
    file close `fh'
    _pygrid_qa_render_help `broken'
    assert r(nbad) == 1

    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local paths ""
    foreach sthlp of local sthlps {
        local paths "`paths' `pkg_dir'/`sthlp'"
    }
    _pygrid_qa_render_help `paths'
    assert r(nbad) == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("help render axis") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Demo dependencies resolve from a public, relocatable source
capture noisily {
    tempname fh
    file open `fh' using "`pkg_dir'/demo/demo_pygrid.do", read text
    local demo_text ""
    file read `fh' line
    while r(eof) == 0 {
        local demo_text `"`demo_text' `line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`demo_text'"', "~/Stata-Tools") == 0
    assert strpos(`"`demo_text'"', "/home/tpcopeland") == 0
    local dev_repo = "Stata" + "-" + "Dev"
    assert strpos(`"`demo_text'"', "`dev_repo'") == 0
    assert strpos(`"`demo_text'"', "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/logdoc") > 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("demo dependency is public and relocatable") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result test_package_contracts ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
