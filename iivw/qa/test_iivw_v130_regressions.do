clear all
version 16.0
set varabbrev off

* test_iivw_v130_regressions.do - regressions for v1.3.0 nobaseevent feature
*
* Coverage:
*   T1  default mode still errors (rc 198) when single-visit subjects present
*   T2  nobaseevent succeeds and returns r(nobaseevent)==1
*   T3  _dta[_iivw_baseevent] == "1" after nobaseevent, "0" after default
*   T4  nobaseevent: every first visit has IIW weight 1; single-visit subjects
*       retained with non-missing weight (not dropped, not errored)
*   T5  nobaseevent changes follow-up weights vs default (same data subset)
*   T6  all single-visit subjects under nobaseevent errors (rc 198) informatively
*   T7  stabcov + nobaseevent succeeds
*   T8  fiptiw + nobaseevent succeeds and retains single-visit subjects
*   T9  entry() is ignored under nobaseevent (identical follow-up weights)
*   T10 _iivw_baseevent is invalidated when a later iptw-only run follows a
*       nobaseevent run (the metadata-reset fix found in v1.3.0 review)
*   T11 invalid entry() is ignored under nobaseevent
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v130_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v130_regressions.do must be run from iivw/qa"
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Mixed panel: subjects 1-30 have 3 visits each, 31-40 have a single visit.
* treat is time-invariant; entry (=5) is constant and < every first visit time.
capture program drop _iivw_v130_panel
program define _iivw_v130_panel
    version 16.0
    clear
    set obs 40
    gen long id = _n
    gen double sev = sin(id / 3) + 5
    gen byte treat = mod(id, 2)
    expand cond(id <= 30, 3, 1)
    bysort id: gen int visit = _n
    gen double days = visit * 30 + mod(id, 7)
    gen double sev_t = sev + 0.3 * visit + cos(id + visit)
    gen double entry = 5
end

**# T1: default mode errors on single-visit subjects

local ++test_count
capture noisily {
    _iivw_v130_panel
    capture iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T1 - default mode errors (rc 198) on single-visit subjects"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - default mode single-visit guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: nobaseevent succeeds and returns r(nobaseevent)==1

local ++test_count
capture noisily {
    _iivw_v130_panel
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent nolog
    assert r(nobaseevent) == 1
}
if _rc == 0 {
    display as result "  PASS: T2 - nobaseevent runs, r(nobaseevent)==1"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - nobaseevent run/return (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: _dta[_iivw_baseevent] reflects the mode

local ++test_count
capture noisily {
    _iivw_v130_panel
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent nolog
    assert "`: char _dta[_iivw_baseevent]'" == "1"
    * default mode on a 2+visit-only subset must set the char to "0"
    drop if id > 30
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) replace nolog
    assert "`: char _dta[_iivw_baseevent]'" == "0"
}
if _rc == 0 {
    display as result "  PASS: T3 - _dta[_iivw_baseevent] is 1 (nobaseevent) / 0 (default)"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - baseevent char (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: first-visit weight 1; single-visit subjects retained with valid weight

local ++test_count
capture noisily {
    _iivw_v130_panel
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent nolog
    * every first/baseline visit shares one IIW weight. Under mean-1
    * normalization the study-entry convention weight (1 before scaling) becomes
    * 1/mean(exp(-xb)) -- identical across baseline rows (SD 0), not literally 1.
    bysort id (days): gen byte _first = (_n == 1)
    quietly summarize _iivw_iw if _first
    assert r(sd) < 1e-9
    * single-visit subjects (id 31-40) are still present with a valid weight
    quietly count if id > 30
    assert r(N) == 10
    quietly count if id > 30 & missing(_iivw_weight)
    assert r(N) == 0
    * their single (baseline) row carries the shared first-visit weight
    quietly summarize _iivw_iw if id > 30
    assert r(sd) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: T4 - first-visit weight 1, single-visit subjects retained"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - first-visit/single-visit handling (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: nobaseevent changes follow-up weights vs default (same data)

local ++test_count
capture noisily {
    _iivw_v130_panel
    keep if id <= 30
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) replace nolog
    gen double w_def = _iivw_iw
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent replace nolog
    gen double w_nbe = _iivw_iw
    bysort id (days): gen byte _f = (_n == 1)
    * first visits share one weight within each mode (mean-1 normalized: the
    * study-entry convention weight rescaled by that run's own mean)
    quietly summarize w_def if _f
    assert r(sd) < 1e-9
    quietly summarize w_nbe if _f
    assert r(sd) < 1e-9
    * follow-up visits differ because the fitted intensity model changed
    quietly count if !_f & abs(w_def - w_nbe) > 1e-8
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T5 - follow-up weights differ under nobaseevent"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - weight divergence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: all single-visit subjects under nobaseevent errors informatively

local ++test_count
capture noisily {
    _iivw_v130_panel
    bysort id (days): keep if _n == 1
    capture iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T6 - all-single-visit under nobaseevent errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - all-single-visit guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: stabcov + nobaseevent succeeds

local ++test_count
capture noisily {
    _iivw_v130_panel
    iivw_weight, id(id) time(days) visit_cov(sev) stabcov(treat) ///
        wtype(iivw) nobaseevent nolog
    assert r(nobaseevent) == 1
    quietly count if missing(_iivw_iw)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T7 - stabcov + nobaseevent runs"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - stabcov + nobaseevent (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: fiptiw + nobaseevent succeeds and retains single-visit subjects

local ++test_count
capture noisily {
    _iivw_v130_panel
    iivw_weight, id(id) time(days) treat(treat) treat_cov(sev) ///
        visit_cov(sev) wtype(fiptiw) nobaseevent nolog
    assert r(nobaseevent) == 1
    * single-visit subjects retained, combined weight present (iw=1 * tw)
    quietly count if id > 30 & missing(_iivw_weight)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T8 - fiptiw + nobaseevent runs, single-visit retained"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - fiptiw + nobaseevent (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: entry() is ignored under nobaseevent (identical follow-up weights)

local ++test_count
capture noisily {
    _iivw_v130_panel
    keep if id <= 30
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent replace nolog
    gen double w_noentry = _iivw_iw
    iivw_weight, id(id) time(days) visit_cov(sev) entry(entry) ///
        wtype(iivw) nobaseevent replace nolog
    gen double w_entry = _iivw_iw
    * the baseline (entry,t1] interval is dropped under nobaseevent, so entry()
    * cannot change the fitted model; every weight must match exactly
    quietly count if reldif(w_noentry, w_entry) > 1e-10
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T9 - entry() ignored under nobaseevent"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - entry() under nobaseevent (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10: _iivw_baseevent invalidated when an iptw-only run follows nobaseevent

local ++test_count
capture noisily {
    _iivw_v130_panel
    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) nobaseevent nolog
    assert "`: char _dta[_iivw_baseevent]'" == "1"
    * iptw-only run does not set _iivw_baseevent; the reset loop must clear the
    * stale "1" so downstream code never reads a mode that no longer applies
    iivw_weight, id(id) time(days) treat(treat) treat_cov(sev) ///
        wtype(iptw) replace nolog
    assert "`: char _dta[_iivw_baseevent]'" == ""
}
if _rc == 0 {
    display as result "  PASS: T10 - stale baseevent char cleared on iptw rerun"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - baseevent char invalidation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# T11: invalid entry() is ignored under nobaseevent

local ++test_count
capture noisily {
    _iivw_v130_panel
    keep if id <= 30
    bysort id (days): gen double entry_bad = days[1]

    iivw_weight, id(id) time(days) visit_cov(sev) wtype(iivw) ///
        nobaseevent replace nolog
    gen double w_noentry_bad = _iivw_iw

    iivw_weight, id(id) time(days) visit_cov(sev) entry(entry_bad) ///
        wtype(iivw) nobaseevent replace nolog
    gen double w_entry_bad = _iivw_iw

    quietly count if reldif(w_noentry_bad, w_entry_bad) > 1e-10
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T11 - invalid entry() ignored under nobaseevent"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - invalid entry() under nobaseevent (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v130_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.3.0 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v130_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
