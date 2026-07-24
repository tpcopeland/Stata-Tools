clear all
version 16.0
set varabbrev off

* test_iivw_interval_contract.do - asymmetric full-refit bootstrap intervals
*
* Regression target:
*   Before v2.3.0, iivw_fit computed e(ci_percentile) internally through
*   Stata's bootstrap prefix but always displayed and stamped a normal/Wald
*   interval. There was no supported way to select the percentile or basic
*   interval or retrieve the interval the package actually reported.
*
* Coverage:
*   T1 citype(percentile) selects the full-refit percentile interval
*   T2 citype(basic) reflects the same full-refit quantiles around e(b)
*   T3 level() is forwarded to the selected asymmetric interval
*   T4 asymmetric citype() refuses a non-bootstrap variance path
*   T5 an unknown citype() refuses with rc 198
*   T6 citype() only selects an interval; it does not rerun the bootstrap
*   T7 the printed coefficient row uses the selected asymmetric endpoints
*   T8 citype(bca) requests clustered-jackknife acceleration and selects BCa
*   T9 BCa retains delete-one FIPTIW fits when outcome and weight frames differ
*   T10 fixed-weight BCa uses its ordinary e(N)/e(sample) jackknife contract
*   T11 BCa acceleration matches an independent delete-one-subject calculation
*   T12 bare FIPTIW prints coefficients only and launches no hidden bootstrap
*   T13 point-only and explicit nominal-inference options cannot be confused
*   T14 replay preserves asymmetric endpoints and postestimation
*   T15 dropping/reloading iivw_fit cannot collide with its replay helper

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_interval_contract.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _v230_data
program define _v230_data
    version 16.0
    clear
    set seed 23017
    set obs 140
    gen long id = _n
    gen double L = rnormal()
    gen byte A = runiform() < invlogit(0.4 + 0.8*L)
    gen double y = 1 + 1.25*A + 0.7*L + rnormal()
    gen double t = 0
    quietly iivw_weight, id(id) time(t) treat(A) treat_cov(L) ///
        wtype(iptw) nolog
end

capture program drop _v230_fiptiw_data
program define _v230_fiptiw_data
    version 16.0
    clear
    set seed 23018
    set obs 80
    gen long id = _n
    gen double L = rnormal()
    gen byte A = runiform() < invlogit(0.3 + 0.6*L)
    gen double C = 7
    expand 6
    bysort id: gen double t = _n - 1
    gen byte entry = (t == 0)
    gen double Z = 0.5*A + 0.3*L + rnormal()
    gen double y = 1 + 1.1*A + 0.4*L + rnormal()
    replace y = . if entry
    quietly iivw_weight, id(id) time(t) visit_cov(Z) treat(A) ///
        treat_cov(L) wtype(fiptiw) censor(C) baseline(entry) nolog
end

**# T1 - percentile interval is selected and stored

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(99) seed(23001)) citype(percentile) nolog replace
    matrix C = e(iivw_ci)
    matrix P = e(ci_percentile)
    assert "`e(iivw_ci_type)'" == "percentile"
    assert rowsof(C) == 2
    assert colsof(C) == colsof(e(b))
    assert mreldif(C, P) < 1e-12
    assert "`e(iivw_vce)'" == "bootstrap"
    assert "`e(iivw_refitweights)'" == "1"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T1: percentile selects the full-refit quantiles"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1"
    display as error "FAIL T1: percentile interval contract"
}

**# T2 - basic interval is the reflected percentile interval

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(99) seed(23002)) citype(basic) nolog replace
    matrix B = e(iivw_ci)
    matrix P = e(ci_percentile)
    local j = colnumb(e(b), "A")
    assert "`e(iivw_ci_type)'" == "basic"
    assert reldif(B[1,`j'], 2*_b[A] - P[2,`j']) < 1e-12
    assert reldif(B[2,`j'], 2*_b[A] - P[1,`j']) < 1e-12
    matrix PB = e(iivw_ci_basic)
    assert mreldif(B, PB) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T2: basic reflects the full-refit percentile endpoints"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2"
    display as error "FAIL T2: basic interval formula"
}

**# T3 - level() controls asymmetric endpoints

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) level(90) ///
        vce(bootstrap, reps(99) seed(23003)) citype(percentile) nolog replace
    matrix C90 = e(iivw_ci)
    matrix P90 = e(ci_percentile)
    assert e(level) == 90
    assert mreldif(C90, P90) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T3: level() reaches the asymmetric interval"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3"
    display as error "FAIL T3: level() forwarding"
}

**# T4 - asymmetric intervals require bootstrap draws

local ++test_count
capture noisily {
    _v230_data
    capture iivw_fit y A, timespec(none) vce(fixed) ///
        citype(percentile) nolog replace
    assert _rc == 198
    capture iivw_fit y A, timespec(none) vce(fixed) ///
        citype(basic) nolog replace
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T4: asymmetric citype() refuses without draws"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4"
    display as error "FAIL T4: non-bootstrap guard"
}

**# T5 - unknown interval name refuses

local ++test_count
capture noisily {
    _v230_data
    capture iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(9) seed(23004)) citype(guess) nolog replace
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T5: unknown citype() refuses"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5"
    display as error "FAIL T5: invalid citype() guard"
}

**# T6 - selecting an interval does not run a second bootstrap

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(99) seed(23005)) citype(wald) nolog replace
    matrix b_wald = e(b)
    matrix V_wald = e(V)
    local rng_wald "`c(rngstate)'"
    scalar reps_wald = e(iivw_bs_reps_completed)

    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(99) seed(23005)) citype(percentile) nolog replace
    matrix b_pct = e(b)
    matrix V_pct = e(V)
    local rng_pct "`c(rngstate)'"
    scalar reps_pct = e(iivw_bs_reps_completed)

    assert mreldif(b_wald, b_pct) == 0
    assert mreldif(V_wald, V_pct) == 0
    assert reps_wald == 99
    assert reps_pct == 99
    assert "`rng_wald'" == "`rng_pct'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T6: citype() reuses one bootstrap run"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6"
    display as error "FAIL T6: citype() changed the bootstrap computation"
}

**# T7 - displayed endpoints come from the selected interval matrix

local ++test_count
capture noisily {
    _v230_data
    tempfile display_log
    log using "`display_log'", text name(v230_display) replace
    iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(99) seed(23006)) citype(percentile) nolog replace
    log close v230_display

    matrix C = e(iivw_ci)
    local j = colnumb(e(b), "A")
    local selected_lo : display %7.4f C[1,`j']
    local selected_hi : display %7.4f C[2,`j']
    local selected_lo = strtrim("`selected_lo'")
    local selected_hi = strtrim("`selected_hi'")
    local z = invnormal((100+e(level))/200)
    local wald_lo : display %7.4f (_b[A] - `z'*_se[A])
    local wald_hi : display %7.4f (_b[A] + `z'*_se[A])
    local wald_lo = strtrim("`wald_lo'")
    local wald_hi = strtrim("`wald_hi'")
    assert "`selected_lo'" != "`wald_lo'" | "`selected_hi'" != "`wald_hi'"

    local found_selected = 0
    local found_normal_table = 0
    file open v230_log using "`display_log'", read text
    file read v230_log line
    while r(eof) == 0 {
        if strpos(`"`line'"', "`selected_lo'") & ///
                strpos(`"`line'"', "`selected_hi'") {
            local found_selected = 1
        }
        if strpos(`"`line'"', "Normal-based") local found_normal_table = 1
        file read v230_log line
    }
    file close v230_log
    assert `found_selected' == 1
    assert `found_normal_table' == 0
}
local t7_rc = _rc
capture log close v230_display
if `t7_rc' == 0 {
    local ++pass_count
    display as result "PASS T7: printed table uses selected bootstrap endpoints"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T7"
    display as error "FAIL T7: printed table did not expose selected endpoints"
}

**# T8 - BCa selection computes acceleration over the resampling clusters

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(49) seed(23007)) citype(bca) nolog replace
    matrix C = e(iivw_ci)
    matrix A = e(accel)
    matrix B = e(ci_bca)
    matrix IB = e(iivw_ci_bca)
    assert "`e(iivw_ci_type)'" == "bca"
    assert mreldif(C, B) < 1e-12
    assert mreldif(C, IB) < 1e-12
    assert rowsof(A) == 1
    assert colsof(A) == colsof(e(b))
    assert !matmissing(A)
    assert "`e(iivw_vce)'" == "bootstrap"
    assert "`e(iivw_refitweights)'" == "1"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T8: BCa uses clustered-jackknife acceleration"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T8"
    display as error "FAIL T8: BCa interval contract"
}

**# T9 - BCa's delete-one count check respects the two-sample FIPTIW contract

local ++test_count
capture noisily {
    _v230_fiptiw_data
    quietly count if !missing(_iivw_weight)
    local frame_N = r(N)
    quietly count if !missing(y, A, L, _iivw_weight)
    local outcome_N = r(N)
    assert `frame_N' > `outcome_N'

    * Without jackknifeopts(n(e(iivw_bs_frame_N))), Stata compares the
    * outcome-model e(N) with the larger weight-model e(sample), discards every
    * successful delete-one refit, and exits 2000. The helper must also
    * physically restrict the weight refit to this marker: jackknife passes an
    * if restriction rather than deleting the subject from memory.
    quietly iivw_fit y A L, timespec(none) ///
        vce(bootstrap, reps(29) seed(23008)) citype(bca) nolog replace
    matrix C = e(iivw_ci_bca)
    matrix ACC = e(accel)
    assert rowsof(C) == 2
    assert colsof(C) == colsof(e(b))
    assert !matmissing(C)
    assert !matmissing(ACC)
    assert "`e(iivw_ci_type)'" == "bca"
    assert e(iivw_bs_reps_failed) == 0
    assert e(iivw_bs_frame_N) == `frame_N'
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T9: BCa retains two-sample FIPTIW delete-one fits"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T9"
    display as error "FAIL T9: BCa lost valid FIPTIW delete-one estimates"
}

**# T10 - fixed-weight BCa does not require the refit helper's frame scalar

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(49) seed(23009) fixedweights) ///
        citype(bca) nolog replace
    matrix C = e(iivw_ci_bca)
    matrix ACC = e(accel)
    assert !matmissing(C)
    assert !matmissing(ACC)
    assert "`e(iivw_vce)'" == "bootstrap-fixedweights"
    assert "`e(iivw_refitweights)'" == "0"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T10: fixed-weight BCa uses its own count contract"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T10"
    display as error "FAIL T10: refit-only BCa count leaked into fixed weights"
}

**# T11 - independent subject jackknife reproduces Stata's acceleration

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(49) seed(23010)) citype(bca) nolog replace
    matrix ACC = e(accel)
    local j = colnumb(e(b), "A")
    local accel_stata = el(ACC, 1, `j')

    tempfile jk
    tempname P
    postfile `P' double(theta) using "`jk'", replace
    forvalues s = 1/140 {
        preserve
        quietly drop if id == `s'
        quietly iivw_weight, id(id) time(t) treat(A) treat_cov(L) ///
            wtype(iptw) nolog replace
        quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
        post `P' (_b[A])
        restore
    }
    postclose `P'

    preserve
    quietly use "`jk'", clear
    quietly summarize theta, meanonly
    local theta_bar = r(mean)
    quietly gen double d2 = (`theta_bar' - theta)^2
    quietly gen double d3 = (`theta_bar' - theta)^3
    quietly summarize d2, meanonly
    local ss2 = r(sum)
    quietly summarize d3, meanonly
    local ss3 = r(sum)
    local accel_manual = `ss3' / (6 * `ss2'^(3/2))
    restore

    assert reldif(`accel_stata', `accel_manual') < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T11: BCa acceleration matches manual subject jackknife"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T11"
    display as error "FAIL T11: BCa acceleration is not the subject jackknife"
}

**# T12 - the bare FIPTIW display is genuinely point-only

local ++test_count
capture noisily {
    _v230_fiptiw_data
    local rng_before "`c(rngstate)'"
    tempfile pointlog
    log using "`pointlog'", text name(v230_point) replace
    iivw_fit y A L, timespec(none) nolog replace
    ereturn display
    log close v230_point

    assert "`e(iivw_ci_type)'" == "none"
    assert "`e(iivw_vce)'" == "none"
    assert "`e(iivw_underlying_vce)'" == "fixed"
    assert "`e(properties)'" == "b"
    assert "`e(iivw_inference_status)'" == "point-only-no-valid-interval"
    assert e(iivw_interval_available) == 0
    assert e(iivw_bs_reps_requested) == 0
    assert "`c(rngstate)'" == "`rng_before'"
    matrix C = e(iivw_ci)
    assert matmissing(C)
    capture confirm matrix e(V)
    assert _rc != 0
    estimates store v230_pointonly
    estimates restore v230_pointonly
    capture confirm matrix e(V)
    assert _rc != 0
    capture estimates replay v230_pointonly
    assert _rc == 0
    capture lincom A
    local lincom_rc = _rc
    assert `lincom_rc' == 321

    local saw_coef = 0
    local saw_inference = 0
    file open v230_plog using "`pointlog'", read text
    file read v230_plog line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Coef.") local saw_coef = 1
        if strpos(`"`line'"', "Std. err.") | ///
                strpos(`"`line'"', "Std. Err.") | ///
                strpos(`"`line'"', "clustered robust SEs") | ///
                strpos(`"`line'"', "P>|z|") | ///
                strpos(`"`line'"', "[95% conf. interval]") | ///
                strpos(`"`line'"', "% CI") | ///
                strpos(`"`line'"', "P(z)") {
            local saw_inference = 1
        }
        file read v230_plog line
    }
    file close v230_plog
    assert `saw_coef' == 1
    assert `saw_inference' == 0
}
local t12_rc = _rc
capture log close v230_point
if `t12_rc' == 0 {
    local ++pass_count
    display as result "PASS T12: bare FIPTIW output is coefficients only"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T12"
    display as error "FAIL T12: point-only output leaked nominal inference"
}

**# T13 - explicit inference is distinct from point-only

local ++test_count
capture noisily {
    _v230_fiptiw_data
    capture iivw_fit y A L, timespec(none) citype(none) ///
        vce(fixed) nolog replace
    assert _rc == 198

    quietly iivw_fit y A L, timespec(none) vce(fixed) nolog replace
    assert "`e(iivw_ci_type)'" == "wald-normal"
    assert "`e(iivw_vce)'" == "fixed"
    assert "`e(iivw_underlying_vce)'" == "fixed"
    assert "`e(iivw_inference_status)'" == "uncleared-fixedweights-analytic"
    assert e(iivw_interval_available) == 1
    assert e(iivw_ci_explicit) == 0

    quietly iivw_fit y A L, timespec(none) citype(none) nolog replace
    assert "`e(iivw_ci_type)'" == "none"
    assert "`e(iivw_vce)'" == "none"
    assert "`e(iivw_underlying_vce)'" == "fixed"
    assert "`e(properties)'" == "b"
    assert e(iivw_interval_available) == 0
    assert e(iivw_ci_explicit) == 1

    capture iivw_fit y A L, timespec(none) collect nolog replace
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T13: point-only and nominal inference stay distinct"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T13"
    display as error "FAIL T13: point-only/nominal option contract"
}

**# T14 - replay preserves selected endpoints and postestimation remains usable

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) ///
        vce(bootstrap, reps(99) seed(23011)) citype(percentile) nolog replace
    matrix C = e(iivw_ci)
    local j = colnumb(e(b), "A")
    local selected_lo : display %7.4f C[1,`j']
    local selected_hi : display %7.4f C[2,`j']
    local selected_lo = strtrim("`selected_lo'")
    local selected_hi = strtrim("`selected_hi'")
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(iivw_underlying_cmd)'" != ""

    estimates store v230_percentile
    tempfile replaylog
    log using "`replaylog'", text name(v230_replay) replace
    estimates replay v230_percentile
    log close v230_replay

    local found_selected = 0
    local found_normal_table = 0
    file open v230_rlog using "`replaylog'", read text
    file read v230_rlog line
    while r(eof) == 0 {
        if strpos(`"`line'"', "`selected_lo'") & ///
                strpos(`"`line'"', "`selected_hi'") {
            local found_selected = 1
        }
        if strpos(`"`line'"', "Normal-based") local found_normal_table = 1
        file read v230_rlog line
    }
    file close v230_rlog
    assert `found_selected' == 1
    assert `found_normal_table' == 0

    capture predict double v230_xb, xb
    assert _rc == 0
    capture lincom A
    assert _rc == 0
    capture margins
    assert _rc == 0
}
local t14_rc = _rc
capture log close v230_replay
if `t14_rc' == 0 {
    local ++pass_count
    display as result "PASS T14: replay preserves interval and postestimation contract"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T14"
    display as error "FAIL T14: replay reverted endpoints or broke postestimation"
}

**# T15 - reloading the ado cannot collide with the resident replay helper

local ++test_count
capture noisily {
    _v230_data
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    assert "`e(cmd)'" == "iivw_fit"

    * Dropping only the public command leaves _iivw_fit_replay resident. The
    * next call reparses iivw_fit.ado and used to fail with r(110) because the
    * helper was defined a second time without first being dropped.
    program drop iivw_fit
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(iivw_underlying_cmd)'" == "glm"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS T15: iivw_fit reloads with its replay helper resident"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T15"
    display as error "FAIL T15: iivw_fit reload collided with replay helper"
}

iivw_qa_summary, name(test_iivw_interval_contract) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
