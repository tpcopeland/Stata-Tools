/*******************************************************************************
* validation_audit_tvsplit.do
*
* Audit-closure known-answer checks for structural-name integrity, daily-date
* origins, and exact anniversary boundaries in tvsplit/tvband/tvage.
*
* Exact anniversary policy: a 29-Feb origin advances on 28-Feb in non-leap
* years and on 29-Feb in leap years.
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-07-13
*******************************************************************************/

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
quietly log using "validation_audit_tvsplit.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display as result "tvtools QA: audit closure for tvsplit -- $S_DATE $S_TIME"

capture program drop _audit_tvsplit_base
program define _audit_tvsplit_base
    clear
    set obs 1
    generate long id = 100
    generate double start = mdy(12, 30, 2000)
    generate double stop = mdy(1, 2, 2001)
    generate double dob = mdy(1, 1, 2000)
    generate double ref = mdy(1, 1, 2000)
    generate double payload = 17
    format start stop dob ref %td
end

capture program drop _audit_tvsplit_aliases
program define _audit_tvsplit_aliases
    foreach spec in ///
        "id(start) start(start) stop(stop)" ///
        "id(stop) start(start) stop(stop)" ///
        "id(id) start(start) stop(start)" {
        _audit_tvsplit_base
        datasignature set
        capture tvsplit, `spec' calendar(, width(1))
        local cmdrc = _rc
        assert `cmdrc' == 198
        datasignature confirm
    }
end

capture program drop _audit_tvsplit_outputs
program define _audit_tvsplit_outputs
    foreach out in id start stop {
        _audit_tvsplit_base
        datasignature set
        capture tvsplit, id(id) start(start) stop(stop) ///
            calendar(, width(1) generate(`out'))
        local cmdrc = _rc
        assert `cmdrc' == 198
        datasignature confirm
    }

    _audit_tvsplit_base
    datasignature set
    capture tvsplit, id(id) start(start) stop(stop) ///
        age(dob, width(1) generate(dob))
    local cmdrc = _rc
    assert `cmdrc' == 198
    datasignature confirm

    _audit_tvsplit_base
    datasignature set
    capture tvsplit, id(id) start(start) stop(stop) ///
        calendar(, width(1) generate(payload))
    local cmdrc = _rc
    assert `cmdrc' == 110
    datasignature confirm
end

capture program drop _audit_tvsplit_origins
program define _audit_tvsplit_origins
    foreach origin in id start stop {
        _audit_tvsplit_base
        datasignature set
        capture tvsplit, id(id) start(start) stop(stop) ///
            age(`origin', width(1))
        local cmdrc = _rc
        assert `cmdrc' == 198
        datasignature confirm

        _audit_tvsplit_base
        datasignature set
        capture tvsplit, id(id) start(start) stop(stop) ///
            elapsed(`origin', width(1) unit(year))
        local cmdrc = _rc
        assert `cmdrc' == 198
        datasignature confirm
    }
end

capture program drop _audit_tvsplit_formats
program define _audit_tvsplit_formats
    _audit_tvsplit_base
    generate double dob_tc = clock("01jan1950", "DMY")
    format dob_tc %tc
    datasignature set
    capture tvsplit, id(id) start(start) stop(stop) age(dob_tc, width(1))
    local cmdrc = _rc
    assert `cmdrc' == 120
    datasignature confirm

    _audit_tvsplit_base
    generate double ref_tC = clock("01jan1950", "DMY")
    format ref_tC %tC
    datasignature set
    capture tvsplit, id(id) start(start) stop(stop) ///
        elapsed(ref_tC, width(1) unit(year))
    local cmdrc = _rc
    assert `cmdrc' == 120
    datasignature confirm

    _audit_tvsplit_base
    replace dob = .
    datasignature set
    capture tvsplit, id(id) start(start) stop(stop) age(dob, width(1))
    local cmdrc = _rc
    assert `cmdrc' == 416
    datasignature confirm

    _audit_tvsplit_base
    format dob %12.0g
    tvsplit, id(id) start(start) stop(stop) age(dob, width(1))
    assert r(n_axes) == 1 & r(n_persons) == 1
    confirm variable ageband

    foreach spec in ///
        "age(dob, width(1.5))" ///
        "elapsed(ref, width(1.5) unit(year))" {
        _audit_tvsplit_base
        datasignature set
        capture tvsplit, id(id) start(start) stop(stop) `spec'
        local cmdrc = _rc
        assert `cmdrc' == 198
        datasignature confirm
    }

    foreach spec in ///
        "type(age) origin(dob) width(1.5)" ///
        "type(elapsed) origin(ref) width(1.5) unit(year)" {
        _audit_tvsplit_base
        datasignature set
        capture tvband, id(id) start(start) stop(stop) `spec'
        local cmdrc = _rc
        assert `cmdrc' == 198
        datasignature confirm
    }
end

capture program drop _audit_tvsplit_birthdays
program define _audit_tvsplit_birthdays
    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(1, 1, 2000)
    generate double start = mdy(12, 30, 2000)
    generate double stop = mdy(1, 2, 2001)
    format dob start stop %td
    tvsplit, id(id) start(start) stop(stop) ///
        age(dob, width(1) generate(attained_age))
    sort start
    assert _N == 2
    assert attained_age[1] == 0 & attained_age[2] == 1
    assert start[1] == mdy(12, 30, 2000)
    assert stop[1] == mdy(12, 31, 2000)
    assert start[2] == mdy(1, 1, 2001)
    assert stop[2] == mdy(1, 2, 2001)

    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(6, 15, 1999)
    generate double start = mdy(6, 14, 2000)
    generate double stop = mdy(6, 16, 2000)
    format dob start stop %td
    tvband, id(id) start(start) stop(stop) type(age) origin(dob) ///
        width(1) generate(attained_age)
    sort start
    assert _N == 2
    assert attained_age[1] == 0 & attained_age[2] == 1
    assert stop[1] == mdy(6, 14, 2000)
    assert start[2] == mdy(6, 15, 2000)

    * Multi-year bands before the origin exercise negative floor behavior.
    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(6, 15, 2000)
    generate double start = mdy(6, 14, 1998)
    generate double stop = mdy(6, 16, 2000)
    format dob start stop %td
    tvsplit, id(id) start(start) stop(stop) ///
        age(dob, width(2) generate(attained_age))
    sort start
    assert _N == 3
    assert attained_age[1] == -4 & attained_age[2] == -2 ///
        & attained_age[3] == 0
    assert stop[1] == mdy(6, 14, 1998)
    assert start[2] == mdy(6, 15, 1998)
    assert stop[2] == mdy(6, 14, 2000)
    assert start[3] == mdy(6, 15, 2000)
end

capture program drop _audit_tvsplit_feb29
program define _audit_tvsplit_feb29
    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(2, 29, 2000)
    generate double start = mdy(2, 27, 2001)
    generate double stop = mdy(3, 1, 2001)
    format dob start stop %td
    tvsplit, id(id) start(start) stop(stop) ///
        age(dob, width(1) generate(attained_age))
    sort start
    assert _N == 2
    assert attained_age[1] == 0 & attained_age[2] == 1
    assert stop[1] == mdy(2, 27, 2001)
    assert start[2] == mdy(2, 28, 2001)

    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(2, 29, 2000)
    generate double start = mdy(2, 27, 2100)
    generate double stop = mdy(3, 2, 2100)
    format dob start stop %td
    tvsplit, id(id) start(start) stop(stop) ///
        age(dob, width(1) generate(attained_age))
    sort start
    assert _N == 2
    assert attained_age[1] == 99 & attained_age[2] == 100
    assert stop[1] == mdy(2, 27, 2100)
    assert start[2] == mdy(2, 28, 2100)

    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(2, 29, 2000)
    generate double entry = mdy(2, 27, 2001)
    generate double exit_d = mdy(3, 1, 2001)
    format dob entry exit_d %td
    tvage, id(id) dob(dob) entry(entry) exit(exit_d) ///
        generate(attained_age) startgen(age_start) stopgen(age_stop)
    sort age_start
    assert _N == 2
    assert attained_age[1] == 0 & attained_age[2] == 1
    assert age_stop[1] == mdy(2, 27, 2001)
    assert age_start[2] == mdy(2, 28, 2001)
end

capture program drop _audit_tvsplit_year_axes
program define _audit_tvsplit_year_axes
    clear
    set obs 1
    generate byte id = 1
    generate double dob = mdy(1, 1, 2000)
    generate double entry = mdy(12, 30, 2000)
    generate double exit_d = mdy(1, 2, 2001)
    format dob entry exit_d %td
    tvage, id(id) dob(dob) entry(entry) exit(exit_d) ///
        generate(attained_age) startgen(age_start) stopgen(age_stop)
    sort age_start
    assert _N == 2
    assert attained_age[1] == 0 & attained_age[2] == 1
    assert age_stop[1] == mdy(12, 31, 2000)
    assert age_start[2] == mdy(1, 1, 2001)

    clear
    set obs 1
    generate byte id = 1
    generate double start = mdy(12, 30, 2000)
    generate double stop = mdy(1, 2, 2001)
    generate double ref = mdy(1, 1, 2000)
    format start stop ref %td
    tvsplit, id(id) start(start) stop(stop) ///
        elapsed(ref, width(1) unit(year) generate(followup_year))
    sort start
    assert _N == 2
    assert followup_year[1] == 0 & followup_year[2] == 1
    assert stop[1] == mdy(12, 31, 2000)
    assert start[2] == mdy(1, 1, 2001)
end

foreach case in aliases outputs origins formats birthdays feb29 year_axes {
    local ++test_count
    capture noisily _audit_tvsplit_`case'
    local case_rc = _rc
    if `case_rc' == 0 {
        display as result "  PASS: `case'"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `case' (error `case_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `case'"
    }
}

display "RESULT: validation_audit_tvsplit tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}

foreach p in _audit_tvsplit_base _audit_tvsplit_aliases ///
    _audit_tvsplit_outputs _audit_tvsplit_origins _audit_tvsplit_formats ///
    _audit_tvsplit_birthdays _audit_tvsplit_feb29 _audit_tvsplit_year_axes {
    capture program drop `p'
}
capture log close _all
