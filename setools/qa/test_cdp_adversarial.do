clear all
version 16.0
capture log close _all
log using "`c(tmpdir)'/test_cdp_adversarial_`c(processid)'.log", replace nomsg
set varabbrev off

* test_cdp_adversarial.do
* Worker A adversarial functional QA for cdp.
* Run from setools/qa:
*   stata-mp -b do test_cdp_adversarial.do

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_test
program define run_test
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  PASS: `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  FAIL: `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures "${gs_failures}; `test_name'"
    }
end

**# Installation surface

capture noisily {
    which cdp
}
local ok = (_rc == 0)
run_test "D1: cdp is installed and discoverable" `ok'

**# Functional options and returns

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date str6 marker
    2 2.0 100 0 "b2a"
    1 2.0 100 0 "b1a"
    2 3.0 200 0 "b2b"
    1 3.0 200 0 "b1b"
    2 3.0 400 0 "b2c"
    1 3.0 400 0 "b1c"
    end
    format edss_dt dx_date %td
    gen long original_order = _n

    tempfile before
    preserve
    keep original_order id edss edss_dt dx_date marker
    rename id id_before
    rename edss edss_before
    rename edss_dt edss_dt_before
    rename dx_date dx_date_before
    rename marker marker_before
    save `before', replace
    restore

    cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_keep) ///
        confirmdays(180) baselinewindow(730) quietly
    assert r(N_persons) == 2
    assert r(N_events) == 2
    assert r(confirmdays) == 180
    assert r(baselinewindow) == 730
    assert "`r(varname)'" == "cdp_keep"
    assert "`r(roving)'" == "no"
    assert _N == 6
    assert original_order == _n

    sort original_order
    merge 1:1 original_order using `before', assert(match) nogen ///
        keepusing(id_before edss_before edss_dt_before dx_date_before marker_before)
    assert id == id_before
    assert edss == edss_before
    assert edss_dt == edss_dt_before
    assert dx_date == dx_date_before
    assert marker == marker_before
    assert cdp_keep == 200
}
local ok = (_rc == 0)
run_test "D2: keepall retains rows/values/order and returns exact scalar/macros" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 0
    1 3.0 200 0
    1 3.0 400 0
    2 2.0 100 0
    2 2.5 200 0
    2 2.5 400 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) generate(cdp_drop) quietly
    assert r(N_persons) == 1
    assert r(N_events) == 1
    assert _N == 3
    assert id == 1
    assert cdp_drop == 200
}
local ok = (_rc == 0)
run_test "D3: default output drops non-CDP patients exactly" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 0
    1 3.5 200 0
    1 3.5 400 0
    1 4.5 500 0
    1 4.5 700 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) roving allevents ///
        confirmdays(180) generate(cdp_event) quietly
    sort id event_num
    assert r(N_persons) == 1
    assert r(N_events) == 2
    assert "`r(roving)'" == "yes"
    assert _N == 2
    assert event_num[1] == 1
    assert cdp_event[1] == 200
    assert baseline_edss_at_event[1] == 2.0
    assert event_num[2] == 2
    assert cdp_event[2] == 500
    assert baseline_edss_at_event[2] == 3.5
}
local ok = (_rc == 0)
run_test "D4: roving allevents returns exact event-level rows and macros" `ok'

**# Expected errors and state restoration

capture noisily {
    clear
    input long id str4 edss long edss_dt long dx_date
    1 "2.0" 100 0
    1 "3.0" 200 0
    end
    format edss_dt dx_date %td

    set varabbrev on
    capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
    assert _N == 2
    assert edss[1] == "2.0"
}
local ok = (_rc == 0)
run_test "D5: string EDSS rejected and varabbrev/data restored" `ok'
set varabbrev off

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 0
    1 3.0 200 0
    end

    set varabbrev on
    capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
    assert _N == 2
}
local ok = (_rc == 0)
run_test "D6: unformatted date variables rejected and varabbrev restored" `ok'
set varabbrev off

capture noisily {
    clear
    input long id double edss double edss_dt double dx_date
    1 2.0 100.5 0
    1 3.0 200   0
    end
    format edss_dt dx_date %td

    capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall
    assert _rc == 109
}
local ok = (_rc == 0)
run_test "D7: fractional Stata daily visit dates are rejected" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 0
    1 3.0 200 0
    end
    format edss_dt dx_date %td

    capture noisily cdp id edss edss_dt, dxdate(dx_date) confirmdays(0)
    assert _rc == 198
}
local ok = (_rc == 0)
run_test "D8: confirmdays(0) rejected" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 0
    1 3.0 200 0
    end
    format edss_dt dx_date %td
    gen cdp_date = .

    capture noisily cdp id edss edss_dt, dxdate(dx_date)
    assert _rc == 110
}
local ok = (_rc == 0)
run_test "D9: default generate collision rejected" `ok'

**# Summary

display as text ""
display as result "Results: " scalar(gs_npass) "/" scalar(gs_ntest) " passed, " scalar(gs_nfail) " failed"
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: ${gs_failures}"
    display "RESULT: test_cdp_adversarial tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_cdp_adversarial tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
log close _all

do "`qa_dir'/_setools_qa_common.do" teardown
