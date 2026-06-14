clear all
set more off
version 16.0

* validation_iivw_known_answers.do - deterministic known-answer checks
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do validation_iivw_known_answers.do

capture log close
tempfile validation_log
log using "`validation_log'", replace nomsg

local here "`c(pwd)'"
local basename = substr("`here'", strrpos("`here'", "/") + 1, .)
if "`basename'" == "qa" {
    local qa_dir "`here'"
}
else {
    local qa_dir "`here'/iivw/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _ka_iivw_dataset_a
program define _ka_iivw_dataset_a
    version 16.0
    clear
    set obs 16
    gen byte id = ceil(_n / 2)
    bysort id: gen byte t = _n
    gen byte x = (id > 4)
end

capture program drop _ka_iivw_dataset_b
program define _ka_iivw_dataset_b
    version 16.0
    clear
    set obs 16
    gen byte id = ceil(_n / 2)
    bysort id: gen byte t = _n
    gen byte x = (id > 4)
    gen byte treat = inlist(id, 1, 5, 6, 7)
end

capture program drop _ka_iivw_dataset_fit
program define _ka_iivw_dataset_fit
    version 16.0
    clear
    set obs 32
    gen byte id = ceil(_n / 2)
    bysort id: gen byte t = _n - 1
    gen byte cell = ceil(id / 4)
    gen byte x = inlist(cell, 3, 4)
    gen byte treat = inlist(cell, 2, 4)
    gen byte clinic = ceil(id / 4)
    gen double resid = (2 * treat - 1) * (2 * x - 1) * (2 * t - 1)
    gen double y = 10 + 2 * treat + 3 * x + 5 * t + resid
    drop cell
end

capture program drop _ka_iivw_assert_unit_weights
program define _ka_iivw_assert_unit_weights
    version 16.0
    syntax , ESS(integer)

    quietly count if _iivw_iw != 1 | _iivw_weight != 1
    assert r(N) == 0
    quietly summarize _iivw_weight
    assert r(mean) == 1
    assert r(sd) == 0
    assert r(min) == 1
    assert r(max) == 1
    tempvar w2
    gen double `w2' = _iivw_weight^2
    quietly summarize _iivw_weight
    local sum_w = r(sum)
    quietly summarize `w2'
    local sum_w2 = r(sum)
    assert abs((`sum_w'^2) / `sum_w2' - `ess') < 1e-12
end

**# Known Answers

local ++test_count
capture noisily {
    iivw
    assert regexm("`r(version)'", "^[0-9]+\.[0-9]+\.[0-9]+$")
    assert "`r(commands)'" == "iivw_weight iivw_balance iivw_fit iivw_exogtest iivw_diagnose"
    assert r(n_commands) == 5
}
if _rc == 0 {
    display as result "  PASS: KA1 - iivw overview returns exact contract"
    local ++pass_count
}
else {
    display as error "  FAIL: KA1 - iivw overview returns (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_a
    iivw_weight, id(id) time(t) visit_cov(x) nolog
    local ret_N = r(N)
    local ret_n_ids = r(n_ids)
    _ka_iivw_assert_unit_weights, ess(16)
    assert `ret_N' == 16
    assert `ret_n_ids' == 8
}
if _rc == 0 {
    display as result "  PASS: KA2 - unstabilized IIW exact unit weights"
    local ++pass_count
}
else {
    display as error "  FAIL: KA2 - unstabilized IIW exactness (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_a
    iivw_weight, id(id) time(t) visit_cov(x) stabcov(x) nolog
    _ka_iivw_assert_unit_weights, ess(16)
}
if _rc == 0 {
    display as result "  PASS: KA3 - stabilized IIW exact unit weights"
    local ++pass_count
}
else {
    display as error "  FAIL: KA3 - stabilized IIW exactness (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_b
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) wtype(iptw) nolog
    gen double expected = cond(treat == 1 & x == 0, 2, ///
        cond(treat == 0 & x == 0, 2/3, ///
        cond(treat == 1 & x == 1, 2/3, 2)))
    gen double diff = abs(_iivw_tw - expected)
    quietly summarize diff
    assert r(max) < 2e-8
    quietly summarize _iivw_weight
    assert abs(r(mean) - 1) < 1e-8
    tempvar w2
    gen double `w2' = _iivw_weight^2
    quietly summarize _iivw_weight
    local sum_w = r(sum)
    quietly summarize `w2'
    local sum_w2 = r(sum)
    assert abs((`sum_w'^2) / `sum_w2' - 12) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KA4 - IPTW exact stabilized weights"
    local ++pass_count
}
else {
    display as error "  FAIL: KA4 - IPTW exactness (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_b
    iivw_weight, id(id) time(t) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) nolog
    assert "`r(weighttype)'" == "fiptiw"
    gen double expected = cond(treat == 1 & x == 0, 2, ///
        cond(treat == 0 & x == 0, 2/3, ///
        cond(treat == 1 & x == 1, 2/3, 2)))
    assert abs(_iivw_iw - 1) < 1e-12
    gen double diff_tw = abs(_iivw_tw - expected)
    gen double diff_w = abs(_iivw_weight - _iivw_iw * _iivw_tw)
    quietly summarize diff_tw
    assert r(max) < 2e-8
    quietly summarize diff_w
    assert r(max) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: KA5 - FIPTIW exact product"
    local ++pass_count
}
else {
    display as error "  FAIL: KA5 - FIPTIW exact product (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_b
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) ///
        wtype(iptw) truncate(25 75) nolog
    assert r(n_truncated) == 4
    local ret_ess = r(ess)
    quietly summarize _iivw_weight
    assert abs(r(min) - 2/3) < 1e-8
    assert abs(r(max) - 4/3) < 1e-8
    assert abs(r(mean) - 5/6) < 1e-8
    assert abs(`ret_ess' - 100/7) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KA6 - truncation exact percentiles and ESS"
    local ++pass_count
}
else {
    display as error "  FAIL: KA6 - truncation exactness (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 24
    gen byte id = ceil(_n / 3)
    bysort id: gen byte t = _n
    gen byte x = mod(id, 2)
    gen double z = 10 * id + t
    iivw_weight, id(id) time(t) visit_cov(x) lagvars(z) nolog
    sort id t
    by id: assert missing(z_lag1) if _n == 1
    by id: assert z_lag1 == z[_n - 1] if _n > 1
    by id: assert _iivw_iw == 1 if _n == 1
    capture confirm variable z_lead1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: KA7 - lagvars exact one-period lag"
    local ++pass_count
}
else {
    display as error "  FAIL: KA7 - lagvars exactness (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_fit
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) wtype(iptw) nolog
    iivw_fit y treat x, timespec(linear) nolog
    assert abs(_b[_cons] - 10) < 1e-12
    assert abs(_b[treat] - 2) < 1e-12
    assert abs(_b[x] - 3) < 1e-12
    assert abs(_b[t] - 5) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: KA8 - iivw_fit exact Gaussian pweight path"
    local ++pass_count
}
else {
    display as error "  FAIL: KA8 - iivw_fit exact Gaussian path (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_fit
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) wtype(iptw) nolog
    iivw_fit y treat x, cluster(clinic) timespec(linear) nolog
    assert abs(_b[_cons] - 10) < 1e-12
    assert abs(_b[treat] - 2) < 1e-12
    assert abs(_b[x] - 3) < 1e-12
    assert abs(_b[t] - 5) < 1e-12
    assert "`e(iivw_cluster)'" == "clinic"
    iivw_fit y treat x, timespec(linear) replace nolog
    assert "`e(iivw_cluster)'" == "id"
}
if _rc == 0 {
    display as result "  PASS: KA9 - cluster metadata with exact coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: KA9 - cluster contract (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_fit
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) wtype(iptw) nolog
    set seed 20260509
    iivw_fit y treat x, timespec(linear) bootstrap(5) nolog
    assert e(N_reps) == 5
    assert "`e(iivw_model)'" == "gee"
    assert abs(_b[treat] - 2) < 1e-12
    assert abs(_b[x] - 3) < 1e-12
    assert abs(_b[t] - 5) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: KA10 - bootstrap wrapper keeps exact point estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: KA10 - bootstrap contract (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_fit
    gen double user_w = 1
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) wtype(iptw) nolog
    capture noisily iivw_fit y x [pw=user_w], timespec(none) nolog
    assert _rc != 0
    capture noisily iivw_fit y x [iw=user_w], timespec(none) nolog
    assert _rc != 0
    capture noisily iivw_weight [pw=user_w], id(id) time(t) ///
        treat(treat) treat_cov(x) wtype(iptw) nolog
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: KA11 - user weight syntax rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: KA11 - user weight syntax contract (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _ka_iivw_dataset_b
    gen double y = 10 + 2 * treat + cond(t == 1, 0.1, -0.1)
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x) wtype(iptw) nolog
    iivw_fit y treat, timespec(none) nolog
    assert abs(_b[_cons] - 10) < 1e-12
    assert abs(_b[treat] - 2) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: KA12 - timespec(none) weighted mean difference"
    local ++pass_count
}
else {
    display as error "  FAIL: KA12 - timespec(none) mean oracle (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Known-answer validation: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "RESULT: `fail_count' KNOWN-ANSWER VALIDATIONS FAILED"
    log close
    exit 1
}

display as result "RESULT: ALL `pass_count' KNOWN-ANSWER VALIDATIONS PASSED"
log close
