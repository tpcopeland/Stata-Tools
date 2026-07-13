clear all
version 16.0
set varabbrev off

* test_iivw_weight_adversarial.do - adversarial tests for iivw_weight
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_weight_adversarial.do
*   stata-mp -b do test_iivw_weight_adversarial.do 5

args run_only
if "`run_only'" == "" local run_only = 0

* Bootstrap from qa/ working directory
local qa_dir "`c(pwd)'"
local base = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`base'" != "qa" {
    display as error "test_iivw_weight_adversarial.do must be run from iivw/qa"
    exit 601
}
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _adv_panel
program define _adv_panel
    version 16.0
    syntax [, N_ids(integer 36) Visits(integer 4) Seed(integer 20260506)]

    clear
    set seed `seed'
    set obs `=`n_ids' * `visits''
    gen long id = ceil(_n / `visits')
    bysort id: gen byte visit = _n
    gen double months = (visit - 1) * 3 + id / 1000
    gen double severity = 1 + 0.03 * id + 0.2 * visit + rnormal(0, 0.08)
    gen double marker = sin(id / 3) + visit / 10
    bysort id (months): gen double sev_bl = severity[1]
    bysort id (months): gen double marker_bl = marker[1]
    gen byte treated = mod(id, 2)
    gen byte outcome = (runiform() < invlogit(-1 + 0.2 * severity))
    gen double entry_ok = 0
end

capture program drop _adv_iptw_uniform
program define _adv_iptw_uniform
    version 16.0

    clear
    set obs 20
    gen long id = ceil(_n / 2)
    bysort id: gen byte visit = _n
    gen double months = visit
    gen byte treated = (id <= 5)
    gen double constant = 1
end

capture program drop _assert_no_weight_outputs
program define _assert_no_weight_outputs
    version 16.0

    foreach v in _iivw_iw _iivw_tw _iivw_weight {
        capture confirm variable `v'
        assert _rc != 0
    }
    foreach ch in _iivw_weighted _iivw_id _iivw_time _iivw_weighttype ///
        _iivw_weight_var _iivw_prefix _iivw_treat _iivw_visit_covars ///
        _iivw_baseevent {
        local val : char _dta[`ch']
        assert "`val'" == ""
    }
end

capture program drop _assert_weight_chars
program define _assert_weight_chars
    version 16.0
    syntax , WTYPE(string) WVAR(string) PREFIX(string) [TREAT(string)]

    local expected_wtype "`wtype'"
    local expected_wvar "`wvar'"
    local expected_prefix "`prefix'"
    local expected_treat "`treat'"

    local got_weighted : char _dta[_iivw_weighted]
    local got_id       : char _dta[_iivw_id]
    local got_time     : char _dta[_iivw_time]
    local got_wtype    : char _dta[_iivw_weighttype]
    local got_wvar     : char _dta[_iivw_weight_var]
    local got_prefix   : char _dta[_iivw_prefix]
    local got_treat    : char _dta[_iivw_treat]

    assert "`got_weighted'" == "1"
    assert "`got_id'" == "id"
    assert "`got_time'" == "months"
    assert "`got_wtype'" == "`expected_wtype'"
    assert "`got_wvar'" == "`expected_wvar'"
    assert "`got_prefix'" == "`expected_prefix'"
    if "`treat'" != "" {
        assert "`got_treat'" == "`expected_treat'"
    }
    else {
        assert "`got_treat'" == ""
    }
end

* Test 1: IIW, IPTW, and FIPTIW mode detection and output variables
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _adv_panel
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) nolog
        assert "`r(weighttype)'" == "iivw"
        confirm variable _iivw_iw
        capture confirm variable _iivw_tw
        assert _rc != 0
        confirm variable _iivw_weight
        _assert_weight_chars, wtype(iivw) wvar(_iivw_weight) prefix(_iivw_)

        _adv_panel
        iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) nolog
        assert "`r(weighttype)'" == "iptw"
        capture confirm variable _iivw_iw
        assert _rc != 0
        confirm variable _iivw_tw
        confirm variable _iivw_weight
        _assert_weight_chars, wtype(iptw) wvar(_iivw_weight) prefix(_iivw_) ///
            treat(treated)

        _adv_panel
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) ///
            treat(treated) treat_cov(sev_bl marker_bl) nolog
        assert "`r(weighttype)'" == "fiptiw"
        confirm variable _iivw_iw
        confirm variable _iivw_tw
        confirm variable _iivw_weight
        gen double product_diff = abs(_iivw_weight - _iivw_iw * _iivw_tw)
        quietly summarize product_diff
        assert r(max) < 1e-10
        _assert_weight_chars, wtype(fiptiw) wvar(_iivw_weight) prefix(_iivw_) ///
            treat(treated)
    }
    if _rc == 0 {
        display as result "  PASS: 1 - weight type modes and outputs"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 1 - weight type modes and outputs (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1"
    }
}

* Test 2: option validation rejects inconsistent IIW/IPTW/FIPTIW requests
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _adv_panel
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) wtype(bogus) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) wtype(iivw) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, id(id) time(months) wtype(iptw) ///
            treat(treated) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) wtype(fiptiw) nolog
        assert _rc == 198
        _assert_no_weight_outputs
    }
    if _rc == 0 {
        display as result "  PASS: 2 - inconsistent options rejected"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 2 - option validation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2"
    }
}

* Test 3: truncation bounds are exact against raw weight percentiles
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _adv_panel, n_ids(48) visits(5) seed(3101)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) ///
            generate(raw_) nolog
        _pctile raw_weight, percentiles(10 90)
        local p10 = r(r1)
        local p90 = r(r2)
        quietly count if raw_weight < `p10' & !missing(raw_weight)
        local n_low = r(N)
        quietly count if raw_weight > `p90' & !missing(raw_weight)
        local n_high = r(N)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) ///
            truncate(10 90) nolog
        assert r(n_truncated) == `n_low' + `n_high'
        quietly summarize _iivw_weight
        assert r(min) >= `p10' - 1e-10
        assert r(max) <= `p90' + 1e-10

        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) truncate(90 10) replace nolog
        assert _rc == 198

        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) truncate(-1 99) replace nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: 3 - truncation exactness and validation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 3 - truncation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3"
    }
}

* Test 4: known-answer IPTW with intercept-only treatment model
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _adv_iptw_uniform
        iivw_weight, id(id) time(months) treat(treated) ///
            treat_cov(constant) wtype(iptw) nolog
        assert r(N) == 20
        assert r(n_ids) == 10
        assert r(mean_weight) == 1
        assert r(sd_weight) == 0
        assert r(min_weight) == 1
        assert r(max_weight) == 1
        assert r(ess) == 20
        assert r(n_truncated) == 0
        local weight_var "`r(weight_var)'"
        quietly count if _iivw_weight != 1 | _iivw_tw != 1
        assert r(N) == 0
        assert "`weight_var'" == "_iivw_weight"
    }
    if _rc == 0 {
        display as result "  PASS: 4 - known-answer IPTW returns"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 4 - known-answer IPTW (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4"
    }
}

* Test 5: lagvars values and collision handling
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _adv_panel
        gen double severity_lag1 = 99
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(marker) lagvars(severity) nolog
        assert _rc == 110

        drop severity_lag1
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(marker) ///
            lagvars(severity) nolog
        confirm variable severity_lag1
        bysort id (months): assert missing(severity_lag1) if _n == 1
        bysort id (months): assert abs(severity_lag1 - severity[_n-1]) < 1e-10 ///
            if _n > 1
    }
    if _rc == 0 {
        display as result "  PASS: 5 - lagvars values and collision handling"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 5 - lagvars (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5"
    }
}

* Test 6: entry() validation rejects missing, varying, equal, and after-first entry
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _adv_panel
        bysort id (months): replace entry_ok = months[1] - 0.5
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) ///
            entry(entry_ok) nolog
        assert r(N) == _N

        _adv_panel
        bysort id (months): gen double entry_bad = months[1]
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) entry(entry_bad) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        bysort id (months): gen double entry_bad = months[1] + 0.01
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) entry(entry_bad) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        gen double entry_bad = 0
        replace entry_bad = . if id == 1
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) entry(entry_bad) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        bysort id (months): gen double entry_bad = months[1] - 0.5 + _n / 100
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) entry(entry_bad) nolog
        assert _rc == 198
        _assert_no_weight_outputs
    }
    if _rc == 0 {
        display as result "  PASS: 6 - entry validation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 6 - entry validation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6"
    }
}

* Test 7: missing id(), missing time(), and duplicate id-time rejected cleanly
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _adv_panel
        replace id = . in 1
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        replace months = . in 2
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        replace months = months[1] in 2
        replace id = id[1] in 2
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) nolog
        assert _rc == 198
        _assert_no_weight_outputs
    }
    if _rc == 0 {
        display as result "  PASS: 7 - id/time missingness and duplicates"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 7 - id/time validation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 7"
    }
}

* Test 8: single-visit ids rejected for IIW but allowed for IPTW-only
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _adv_panel, n_ids(20) visits(1)
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_iptw_uniform
        bysort id (months): keep if _n == 1
        iivw_weight, id(id) time(months) treat(treated) ///
            treat_cov(constant) wtype(iptw) nolog
        assert r(N) == 10
        assert r(n_ids) == 10
        quietly count if _iivw_weight != 1
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: 8 - single-visit handling"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 8 - single-visit handling (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 8"
    }
}

* Test 9: visit and treatment missingness paths are explicit
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _adv_panel, n_ids(24) visits(4)
        replace severity = . if id == 1 & visit == 1
        replace severity = . if id == 2 & visit == 3
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) nolog
        * id==1 v1 is a first obs with a missing covariate: it takes the
        * baseline-convention weight (shared across first obs after mean-1
        * normalization, no longer literally 1) and is not dropped
        assert !missing(_iivw_weight) if id == 1 & visit == 1
        tempvar _t9first
        bysort id (months): gen byte `_t9first' = (_n == 1)
        quietly summarize _iivw_weight if `_t9first'
        assert r(sd) < 1e-9
        assert missing(_iivw_weight) if id == 2 & visit == 3
        quietly count if missing(_iivw_weight)
        assert r(N) >= 1

        _adv_panel
        replace treated = . if id == 1 & visit == 2
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) treat(treated) treat_cov(sev_bl) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        replace treated = . if id == 1
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) treat(treated) treat_cov(sev_bl) nolog
        assert _rc == 198
        _assert_no_weight_outputs
    }
    if _rc == 0 {
        display as result "  PASS: 9 - covariate and treatment missingness"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 9 - missingness (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 9"
    }
}

* Test 10: prefix collisions and custom prefix metadata
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _adv_panel
        gen double alt_weight = 42
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) generate(alt_) nolog
        assert _rc == 110

        drop alt_weight
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            generate(alt_) nolog
        confirm variable alt_iw
        confirm variable alt_weight
        assert "`r(weight_var)'" == "alt_weight"
        _assert_weight_chars, wtype(iivw) wvar(alt_weight) prefix(alt_)

        _adv_panel
        local long_prefix "abcdefghijklmnopqrstuvwx12"
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) treat(treated) treat_cov(sev_bl) ///
            generate(`long_prefix') nolog
        assert _rc == 198
        foreach suffix in iw tw weight time_sq time_cu tns1 cat_x ix_x_time {
            capture confirm variable `long_prefix'`suffix'
            assert _rc != 0
        }
        foreach ch in _iivw_weighted _iivw_id _iivw_time _iivw_weighttype ///
            _iivw_weight_var _iivw_prefix _iivw_treat {
            local val : char _dta[`ch']
            assert "`val'" == ""
        }
    }
    if _rc == 0 {
        display as result "  PASS: 10 - prefix collisions and metadata"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 10 - prefix handling (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 10"
    }
}

* Test 11: varabbrev restored on success and validation error
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        _adv_panel
        set varabbrev on
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        assert "`c(varabbrev)'" == "on"

        _adv_panel
        set varabbrev on
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) wtype(bad) nolog
        assert _rc == 198
        assert "`c(varabbrev)'" == "on"
        set varabbrev off
    }
    if _rc == 0 {
        display as result "  PASS: 11 - varabbrev restored"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 11 - varabbrev restoration (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 11"
    }
}

* Test 12: sort order and source variables preserved
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        _adv_panel, n_ids(30) visits(4) seed(1212)
        gsort -severity id months
        gen long order_before = _n
        gen double severity_before = severity
        gen double months_before = months
        gen byte treated_before = treated

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity marker) ///
            treat(treated) treat_cov(sev_bl marker_bl) nolog

        assert order_before == _n
        assert severity == severity_before
        assert months == months_before
        assert treated == treated_before
        assert _N == 120
    }
    if _rc == 0 {
        display as result "  PASS: 12 - sort and data preservation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 12 - data preservation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 12"
    }
}

* Test 13: failed validation-stage rerun preserves prior metadata (v1.0.6+)
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        _adv_panel
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        local weighted_before : char _dta[_iivw_weighted]
        assert "`weighted_before'" == "1"

        gen byte bad_treat = 2
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity) treat(bad_treat) treat_cov(sev_bl) ///
            generate(bad_) nolog
        assert _rc == 198
        * v1.0.6+: validation-stage failure preserves prior metadata
        assert "`: char _dta[_iivw_weighted]'"   == "1"
        assert "`: char _dta[_iivw_weighttype]'" == "iivw"
        assert "`: char _dta[_iivw_weight_var]'" == "_iivw_weight"
    }
    if _rc == 0 {
        display as result "  PASS: 13 - failed validation preserves prior metadata"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 13 - stale metadata (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 13"
    }
}

* Test 14: logit separation fails cleanly without generated weights
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        clear
        set obs 20
        gen long id = ceil(_n / 2)
        bysort id: gen byte visit = _n
        gen double months = visit
        gen byte sep = (id <= 5)
        gen byte treated = sep

        capture noisily iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sep) wtype(iptw) nolog
        assert _rc != 0
        _assert_no_weight_outputs
    }
    if _rc == 0 {
        display as result "  PASS: 14 - logit separation clean failure"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 14 - logit separation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 14"
    }
}

* Test 15: adversarial Cox collinearity either succeeds with valid weights or fails cleanly
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        _adv_panel, n_ids(30) visits(5) seed(1515)
        gen double severity_clone = 2 * severity
        capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity severity_clone) nolog
        local rc = _rc
        if `rc' == 0 {
            assert r(N) == _N
            assert r(ess) > 0
            assert r(ess) <= r(N) + 1e-6
            quietly count if missing(_iivw_weight) | _iivw_weight <= 0
            assert r(N) == 0
        }
        else {
            _assert_no_weight_outputs
        }
    }
    if _rc == 0 {
        display as result "  PASS: 15 - Cox collinearity handled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 15 - Cox collinearity (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 15"
    }
}

* Test 16: IPTW-only ignores visit_cov() but rejects IIW-only options
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _adv_panel
        iivw_weight, id(id) time(months) visit_cov(severity marker) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) nolog
        assert "`r(weighttype)'" == "iptw"
        assert "`r(visit_covars)'" == ""
        assert "`: char _dta[_iivw_visit_covars]'" == ""
        capture confirm variable severity_lag1
        assert _rc != 0

        _adv_panel
        capture noisily iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) ///
            lagvars(severity) nolog
        assert _rc == 198
        capture confirm variable severity_lag1
        assert _rc != 0
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) ///
            stabcov(severity) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) ///
            entry(entry_ok) nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) ///
            efron nolog
        assert _rc == 198
        _assert_no_weight_outputs

        _adv_panel
        capture noisily iivw_weight, id(id) time(months) ///
            treat(treated) treat_cov(sev_bl marker_bl) wtype(iptw) ///
            nobaseevent nolog
        assert _rc == 198
        _assert_no_weight_outputs
    }
    if _rc == 0 {
        display as result "  PASS: 16 - IPTW-only visit-model option contract"
        local ++pass_count
    }
    else {
        display as error "  FAIL: 16 - IPTW-only visit-model options (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 16"
    }
}

* Summary
display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_weight_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_weight_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
