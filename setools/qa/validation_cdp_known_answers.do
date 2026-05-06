clear all
version 16.0
capture log close _all
log using "validation_cdp_known_answers.log", replace nomsg
set varabbrev off

* validation_cdp_known_answers.do
* Worker A hand-computable known-answer validation for cdp.
* Run from setools/qa:
*   stata-mp -b do validation_cdp_known_answers.do

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_val
program define run_val
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

**# Baseline selection

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 1.0  50 100
    1 2.0 110 100
    1 2.5 200 100
    1 3.0 400 100
    1 3.0 510 100
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) ///
        confirmdays(100) keepall generate(cdp_b1) quietly
    quietly summarize cdp_b1 if id == 1, meanonly
    assert r(mean) == 400
    assert r(N) == 5
    assert r(min) == 400
    assert r(max) == 400
}
local ok = (_rc == 0)
run_val "K1: first in-window baseline beats earlier pre-diagnosis visit" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 1000
    1 3.0 200 1000
    1 3.0 400 1000
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) ///
        confirmdays(100) keepall generate(cdp_b2) quietly
    quietly summarize cdp_b2 if id == 1, meanonly
    assert r(mean) == 200
    assert r(N) == 3
}
local ok = (_rc == 0)
run_val "K2: no in-window visit falls back to earliest available EDSS" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 5.5 100 0
    1 6.0 200 0
    1 6.0 400 0
    2 5.5 100 0
    2 6.5 200 0
    2 6.5 400 0
    3 5.6 100 0
    3 6.1 200 0
    3 6.1 400 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) confirmdays(180) ///
        keepall generate(cdp_thr) quietly
    assert r(N_events) == 2
    quietly count if id == 1 & !missing(cdp_thr)
    assert r(N) == 0
    quietly summarize cdp_thr if id == 2, meanonly
    assert r(mean) == 200
    quietly summarize cdp_thr if id == 3, meanonly
    assert r(mean) == 200
}
local ok = (_rc == 0)
run_val "K3: baseline EDSS 5.5 uses 1.0 threshold; >5.5 uses 0.5" `ok'

**# Confirmation and same-day ties

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.0 100 0
    1 2.5 160 0
    1 3.5 200 0
    1 3.5 260 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) confirmdays(50) ///
        keepall generate(cdp_retry) quietly
    local nevents = r(N_events)
    quietly summarize cdp_retry if id == 1, meanonly
    assert r(mean) == 200
    assert `nevents' == 1
}
local ok = (_rc == 0)
run_val "K4: failed first candidate is excluded and later candidate is confirmed" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.5 100 0
    1 1.5 100 0
    1 2.5 150 0
    1 2.5 330 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) confirmdays(180) ///
        keepall generate(cdp_tie) quietly
    local nevents = r(N_events)
    quietly summarize cdp_tie if id == 1, meanonly
    assert r(mean) == 150
    assert `nevents' == 1
    assert r(N) == 4
}
local ok = (_rc == 0)
run_val "K5: same-day baseline tie uses lower EDSS even when input is high-before-low" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.0 100 0
    1 3.0 279 0
    2 2.0   0 0
    2 3.0 100 0
    2 3.0 280 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) confirmdays(180) ///
        keepall generate(cdp_edge) quietly
    assert r(N_events) == 1
    quietly count if id == 1 & !missing(cdp_edge)
    assert r(N) == 0
    quietly summarize cdp_edge if id == 2, meanonly
    assert r(mean) == 100
}
local ok = (_rc == 0)
run_val "K6: confirmation is inclusive at exactly confirmdays and excludes 179 days" `ok'

**# Missing values and roving baseline

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0 100 0
    1 .   150 0
    1 3.0 200 0
    1 3.0 400 0
    2 2.0 100 .
    2 3.0 200 .
    3 2.0 .   0
    3 3.0 200 0
    3 3.0 400 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_miss) quietly
    assert r(N_events) == 1
    quietly summarize cdp_miss if id == 1, meanonly
    assert r(mean) == 200
    quietly count if id == 2 & !missing(cdp_miss)
    assert r(N) == 0
    quietly count if id == 3 & !missing(cdp_miss)
    assert r(N) == 0
}
local ok = (_rc == 0)
run_val "K7: missing EDSS/date rows are dropped, missing dx excludes that patient" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.5 100 0
    1 3.5 200 0
    1 4.5 300 0
    1 4.5 500 0
    end
    format edss_dt dx_date %td

    cdp id edss edss_dt, dxdate(dx_date) roving allevents ///
        confirmdays(90) generate(cdp_rov) quietly
    sort event_num
    assert r(N_persons) == 1
    assert r(N_events) == 2
    assert "`r(roving)'" == "yes"
    assert _N == 2
    assert event_num[1] == 1
    assert cdp_rov[1] == 100
    assert baseline_edss_at_event[1] == 2.0
    assert event_num[2] == 2
    assert cdp_rov[2] == 300
    assert baseline_edss_at_event[2] == 3.5
}
local ok = (_rc == 0)
run_val "K8: roving allevents has exact event dates and baselines" `ok'

**# Summary

display as text ""
display as result "Results: " scalar(gs_npass) "/" scalar(gs_ntest) " passed, " scalar(gs_nfail) " failed"
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: ${gs_failures}"
    display "RESULT: validation_cdp_known_answers tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_cdp_known_answers tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
log close _all
