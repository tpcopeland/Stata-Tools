clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_types.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# String identifiers match exactly
local ++test_count
capture noisily {
    tempfile events
    clear
    input str12 id double visit value
    "person-a" 90 9
    "person-b" 210 21
    end
    save `events'
    clear
    input str12 id double anchor
    "person-b" 200
    "person-a" 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert got[1] == 21 & got[2] == 9
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Numeric identifier storage types and value labels do not change matching
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 100 10
    2 200 20
    end
    save `events'
    clear
    input byte id double anchor
    1 100
    2 200
    end
    label define idlbl 1 "One" 2 "Two"
    label values id idlbl
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert got[1] == 10 & got[2] == 20
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# int, long, and double daily dates compare in common units
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id long visit double value
    1 100 10
    end
    format %td visit
    save `events'
    clear
    input long id int anchor
    1 100
    end
    format %td anchor
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got) gapname(gap)
    assert got == 10 & gap == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# %tc windows and gaps are converted to days
local ++test_count
capture noisily {
    tempfile events
    clear
    set obs 2
    generate long id = 1
    generate double visit = clock("01jan2020 00:00:00", "DMYhms") + ///
        cond(_n == 1, -12 * 60 * 60 * 1000, 36 * 60 * 60 * 1000)
    generate double value = _n
    format %tc visit
    save `events'
    clear
    set obs 1
    generate long id = 1
    generate double anchor = clock("01jan2020 00:00:00", "DMYhms")
    format %tc anchor
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) window(-1 1) ///
        generate(got) gapname(gap)
    assert got == 1
    assert abs(gap + 0.5) < 1e-12
    assert r(N_eligible) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Daily/%tc mismatches and unsupported time formats return 109
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 100 10
    end
    format %td visit
    save `events'
    clear
    input long id double anchor
    1 100
    end
    format %tc anchor
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest)
    assert _rc == 109
    format %tm anchor
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest)
    assert _rc == 109
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# String dates and identifier type mismatches return 109
local ++test_count
capture noisily {
    tempfile string_dates string_ids message_log
    clear
    input long id str10 visit double value
    1 "2020-01-01" 10
    end
    save `string_dates'
    clear
    input str4 id double visit value
    "1" 100 10
    end
    save `string_ids'
    clear
    input long id double anchor
    1 100
    end
    capture log close errmsg
    log using "`message_log'", replace text name(errmsg) nomsg
    capture noisily asof value using `string_dates', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest)
    local date_rc = _rc
    log close errmsg
    assert `date_rc' == 109

    tempname message_handle
    local saw_hint = 0
    file open `message_handle' using "`message_log'", read text
    file read `message_handle' line
    while r(eof) == 0 {
        if strpos(lower(`"`line'"'), "datefix") local saw_hint = 1
        file read `message_handle' line
    }
    file close `message_handle'
    assert `saw_hint' == 1
    capture noisily asof value using `string_ids', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest)
    assert _rc == 109
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Frame and file sources give identical results without changing the frame
local ++test_count
capture noisily {
    tempfile events master file_result
    clear
    input long id double visit value
    1 90 9
    1 110 11
    2 200 20
    end
    save `events'
    frame create visits
    frame visits: use `events', clear
    frame visits: generate byte sentinel = 1
    clear
    input long id double anchor
    1 100
    2 200
    end
    save `master'
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(file_pick)
    save `file_result'
    use `master', clear
    asof value using visits, frame(visits) id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest) generate(frame_pick)
    merge 1:1 id using `file_result', keepusing(file_pick) assert(3) nogen
    assert frame_pick == file_pick
    frame visits: quietly count
    assert r(N) == 3
    frame visits: assert sentinel == 1
    frame drop visits
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_types tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
