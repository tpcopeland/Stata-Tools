clear all
version 16.0
capture log close _all
log using "validation_cdp_threetier_confirmtype.log", replace nomsg
set varabbrev off

* validation_cdp_threetier_confirmtype.do
* Known-answer (DGP-style) validation for the cdp threshold rule (threetier),
* confirmation rule (confirmtype), and study-exit censoring (exit()).
*
* Every expected value is hand-derived from the documented rules, independent
* of the command's own output:
*   threetier  : >=1.5 if baseline 0, >=1.0 if 1.0-5.5, >=0.5 if >5.5
*   two-tier   : >=1.0 if baseline <=5.5, else >=0.5
*   sustained  : confirmation EDSS = MIN over all visits at/after cand+confirmdays
*   visit      : confirmation EDSS = the FIRST visit at/after cand+confirmdays
*   exit()     : a confirmed CDP date strictly after the exit date is censored
*
* Dates are raw Stata day numbers; only the arithmetic matters.
* Run from setools/qa:
*   stata-mp -b do validation_cdp_threetier_confirmtype.do

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

**# T1: three-tier raises the baseline-0 bar from +1.0 to +1.5

* Baseline EDSS 0; later EDSS reaches only 1.0 (sustained).
*   two-tier : threshold 1.0 -> change 1.0 confirms -> CDP at day 100.
*   three-tier: threshold 1.5 -> change 1.0 does NOT confirm -> no event.
capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 0.0   0 0
    1 1.0 100 0
    1 1.0 300 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        keepall generate(cdp_2t) quietly
    local n2 = r(N_events)
    quietly summarize cdp_2t if id == 1, meanonly
    assert `n2' == 1 & r(mean) == 100
}
local ok = (_rc == 0)
run_val "T1a: two-tier confirms +1.0 from baseline 0 at day 100" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 0.0   0 0
    1 1.0 100 0
    1 1.0 300 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        threetier keepall generate(cdp_3t) quietly
    assert r(N_events) == 0
    quietly count if id == 1 & !missing(cdp_3t)
    assert r(N) == 0
}
local ok = (_rc == 0)
run_val "T1b: three-tier rejects +1.0 from baseline 0 (needs +1.5)" `ok'

**# T2: three-tier confirms at exactly +1.5 from baseline 0

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 0.0   0 0
    1 1.5 100 0
    1 1.5 300 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        threetier keepall generate(cdp_3b) quietly
    local ev = r(N_events)
    quietly summarize cdp_3b if id == 1, meanonly
    assert `ev' == 1 & r(mean) == 100
}
local ok = (_rc == 0)
run_val "T2: three-tier confirms exactly +1.5 from baseline 0" `ok'

**# T3: three-tier leaves the 1.0-5.5 and >5.5 tiers unchanged

* Baseline 2.0 (mid tier, +1.0) and baseline 6.0 (high tier, +0.5) both
* progress identically under two-tier and three-tier.
capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.0 100 0
    1 3.0 300 0
    2 6.0   0 0
    2 6.5 100 0
    2 6.5 300 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        threetier keepall generate(cdp_mix3) quietly
    local ev3 = r(N_events)
    quietly summarize cdp_mix3 if id == 1, meanonly
    local d1 = r(mean)
    quietly summarize cdp_mix3 if id == 2, meanonly
    local d2 = r(mean)
    assert `ev3' == 2 & `d1' == 100 & `d2' == 100
}
local ok = (_rc == 0)
run_val "T3: three-tier mid/high tiers match two-tier (+1.0 / +0.5)" `ok'

**# T4/T5: confirmtype visit vs sustained on a later-dip trajectory

* Baseline 2.0; progression to 3.0 at day 100; confirmation visits at
* day 300 (3.0) and day 400 (2.0, a dip). cand+confirmdays = 280.
*   visit    : first visit >=280 is day 300 (3.0) >= 3.0 -> confirmed at 100.
*   sustained: min over {3.0, 2.0} = 2.0 < 3.0 -> rejected, no event.
capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.0 100 0
    1 3.0 300 0
    1 2.0 400 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        confirmtype(visit) keepall generate(cdp_vis) quietly
    local ev = r(N_events)
    local ct "`r(confirmtype)'"
    quietly summarize cdp_vis if id == 1, meanonly
    assert `ev' == 1 & r(mean) == 100
    assert "`ct'" == "visit"
}
local ok = (_rc == 0)
run_val "T4: confirmtype(visit) confirms via first post-window visit" `ok'

capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.0 100 0
    1 3.0 300 0
    1 2.0 400 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        confirmtype(sustained) keepall generate(cdp_sus) quietly
    local ev = r(N_events)
    local ct "`r(confirmtype)'"
    assert `ev' == 0
    quietly count if id == 1 & !missing(cdp_sus)
    assert r(N) == 0
    assert "`ct'" == "sustained"
}
local ok = (_rc == 0)
run_val "T5: confirmtype(sustained) rejects the same trajectory (later dip)" `ok'

**# T6: exit() censors a CDP strictly after study exit; boundary is kept

* All three patients confirm CDP at day 100.
*   id1 exit=50  -> 100 > 50  -> censored
*   id2 exit=500 -> 100 < 500 -> kept
*   id3 exit=100 -> 100 == 100 (not strictly after) -> kept
capture noisily {
    clear
    input long id double edss long edss_dt long dx_date long exitv
    1 2.0   0 0  50
    1 3.0 100 0  50
    1 3.0 300 0  50
    2 2.0   0 0 500
    2 3.0 100 0 500
    2 3.0 300 0 500
    3 2.0   0 0 100
    3 3.0 100 0 100
    3 3.0 300 0 100
    end
    format edss_dt dx_date %td
    format exitv %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        exit(exitv) keepall generate(cdp_ex) eventvar(cdp_ev) quietly
    assert r(N_censored_exit) == 1
    assert r(N_persons) == 2
    assert r(N_events) == 2
    quietly count if id == 1 & !missing(cdp_ex)
    assert r(N) == 0
    quietly summarize cdp_ex if id == 2, meanonly
    assert r(mean) == 100
    quietly summarize cdp_ex if id == 3, meanonly
    assert r(mean) == 100
}
local ok = (_rc == 0)
run_val "T6: exit() censors post-exit CDP; on-exit boundary retained" `ok'

**# T7: eventvar 0/1 indicator matches the confirmed set exactly

* id1 progresses (baseline 2 -> 3 sustained); id2 never progresses.
capture noisily {
    clear
    input long id double edss long edss_dt long dx_date
    1 2.0   0 0
    1 3.0 100 0
    1 3.0 300 0
    2 2.0   0 0
    2 2.5 100 0
    2 2.5 300 0
    end
    format edss_dt dx_date %td
    cdp id edss edss_dt, dxdate(dx_date) baselinewindow(30) confirmdays(180) ///
        keepall generate(cdp_e) eventvar(cdp_flag) quietly
    assert r(N_events) == 1
    quietly summarize cdp_flag if id == 1, meanonly
    assert r(mean) == 1
    quietly summarize cdp_flag if id == 2, meanonly
    assert r(mean) == 0
    quietly summarize cdp_flag, meanonly
    assert r(sum) == 3
}
local ok = (_rc == 0)
run_val "T7: eventvar flags exactly the confirmed progressor rows" `ok'

**# Summary

display as text ""
display as result "Results: " scalar(gs_npass) "/" scalar(gs_ntest) " passed, " scalar(gs_nfail) " failed"
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: ${gs_failures}"
    display "RESULT: validation_cdp_threetier_confirmtype tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_cdp_threetier_confirmtype tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
log close _all
