* test_cdp_roving_determinism.do
* Regression tests for v1.4.1 cdp determinism fixes:
*   1. allevents+roving output: the retained covariate row per person is
*      deterministically the FIRST row of the original data (the person-level
*      reduction before the 1:m merge is keyed on original order, not left to
*      Stata's non-stable sort).
*   2. Roving re-baseline: when the first visit after a confirmed event has
*      same-day duplicate EDSS measurements, the LOWER EDSS becomes the new
*      baseline (package-wide tie convention), so the second event's threshold
*      is deterministic.
*
* Run from setools/qa:
*     stata-mp -b do test_cdp_roving_determinism.do

clear all
version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

local nfail = 0

**# Test 1: roving re-baseline uses the lower EDSS on same-day duplicates
* Person 1 timeline (dx 01jan2020):
*   01jan2020 EDSS 2.0  -> baseline 1
*   01mar2020 EDSS 3.5  -> event 1 candidate (+1.5 >= 1.0)
*   01oct2020 EDSS 3.5  \  same-day duplicate visits: re-baseline must
*   01oct2020 EDSS 4.5  /  deterministically pick 3.5
*   01jan2021 EDSS 5.0  -> event 2 candidate (+1.5 from 3.5; only +0.5 from 4.5)
*   01aug2021 EDSS 5.0  -> sustains both confirmations
* Expected: 2 events; event 2 baseline_edss_at_event == 3.5, date 01jan2021.
clear
set obs 6
gen long id = 1
gen long dx = td(01jan2020)
gen long visit_dt = .
gen double edss = .
replace visit_dt = td(01jan2020) in 1
replace edss = 2.0 in 1
replace visit_dt = td(01mar2020) in 2
replace edss = 3.5 in 2
replace visit_dt = td(01oct2020) in 3
replace edss = 3.5 in 3
replace visit_dt = td(01oct2020) in 4
replace edss = 4.5 in 4
replace visit_dt = td(01jan2021) in 5
replace edss = 5.0 in 5
replace visit_dt = td(01aug2021) in 6
replace edss = 5.0 in 6
format dx visit_dt %td

cdp id edss visit_dt, dxdate(dx) roving allevents quietly

capture {
    assert r(N_events) == 2
    assert _N == 2
}
if _rc {
    display as error "  [FAIL] roving same-day re-baseline: expected 2 CDP events"
    local ++nfail
}
else display as result "  [PASS] roving same-day re-baseline: 2 CDP events found"

capture {
    sort event_num
    assert cdp_date[1] == td(01mar2020)
    assert baseline_edss_at_event[1] == 2.0
    assert cdp_date[2] == td(01jan2021)
    assert baseline_edss_at_event[2] == 3.5
}
if _rc {
    display as error "  [FAIL] roving same-day re-baseline: second baseline must be the lower EDSS (3.5)"
    local ++nfail
}
else display as result "  [PASS] roving same-day re-baseline: second baseline is the lower same-day EDSS"

**# Test 2: allevents+roving retains each person's FIRST original row's covariates
* Rows are entered in REVERSE chronological order, so original-order row 1 per
* person is the LAST visit. The retained covariate value must be that row's.
clear
set obs 8
gen long id = .
gen long dx = td(01jan2020)
gen long visit_dt = .
gen double edss = .
gen str8 tag = ""
* Person 1: reverse chronological entry; tag marks each visit uniquely.
replace id = 1 in 1
replace visit_dt = td(01dec2020) in 1
replace edss = 4.0 in 1
replace tag = "p1_last" in 1
replace id = 1 in 2
replace visit_dt = td(01jun2020) in 2
replace edss = 4.0 in 2
replace tag = "p1_mid" in 2
replace id = 1 in 3
replace visit_dt = td(01mar2020) in 3
replace edss = 3.5 in 3
replace tag = "p1_prog" in 3
replace id = 1 in 4
replace visit_dt = td(01jan2020) in 4
replace edss = 2.0 in 4
replace tag = "p1_base" in 4
* Person 2: same shape, entered forward, to guard both orderings.
replace id = 2 in 5
replace visit_dt = td(01jan2020) in 5
replace edss = 2.0 in 5
replace tag = "p2_base" in 5
replace id = 2 in 6
replace visit_dt = td(01mar2020) in 6
replace edss = 3.5 in 6
replace tag = "p2_prog" in 6
replace id = 2 in 7
replace visit_dt = td(01jun2020) in 7
replace edss = 4.0 in 7
replace tag = "p2_mid" in 7
replace id = 2 in 8
replace visit_dt = td(01dec2020) in 8
replace edss = 4.0 in 8
replace tag = "p2_last" in 8
format dx visit_dt %td

cdp id edss visit_dt, dxdate(dx) roving allevents quietly

capture {
    assert tag == "p1_last" if id == 1
    assert tag == "p2_base" if id == 2
}
if _rc {
    display as error "  [FAIL] allevents covariate row: must be each person's first original row"
    local ++nfail
}
else display as result "  [PASS] allevents covariate row is deterministically the first original row"

**# Summary
if `nfail' > 0 {
    display as error "test_cdp_roving_determinism: `nfail' test group(s) FAILED"
    exit 9
}
display as result "test_cdp_roving_determinism: ALL TESTS PASSED"
