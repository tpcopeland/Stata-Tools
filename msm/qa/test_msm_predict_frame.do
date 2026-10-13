* test_msm_predict_frame.do
* msm 2.0.0: msm_predict, frame(name[, replace]) and the r(rd)/r(sd) contrast
* matrix. The frame is eplot's graph-ready schema (label estimate ll ul rowtype)
* plus horizon and strategy keys; every value must equal r(predictions).

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_predict_frame.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

use "`pkg_dir'/msm_example.dta", clear
quietly {
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
}
tempfile fitted
quietly save "`fitted'"

**# F1: frame rows equal r(predictions), in horizon x strategy order
local ++test_count
capture noisily {
    capture frame drop pf
    msm_predict, times(1 3 5 7 9) samples(60) difference seed(4401) frame(pf)
    assert "`r(frame)'" == "pf"
    tempname P
    matrix `P' = r(predictions)
    confirm frame pf
    frame pf {
        assert _N == 15
        confirm string variable label strategy rowtype
        confirm numeric variable horizon estimate ll ul
        assert rowtype == "effect"
        assert "`: char _dta[msm_predict_type]'" == "cum_inc"
        assert "`: char _dta[msm_predict_level]'" == "95"
        assert "`: char _dta[msm_predict_samples]'" == "60"
        assert "`: char _dta[msm_predict_seed]'" == "4401"
        forvalues k = 1/5 {
            local r0 = 3 * `k' - 2
            local r1 = 3 * `k' - 1
            local rd = 3 * `k'
            assert horizon[`r0'] == `P'[`k', 1] & horizon[`rd'] == `P'[`k', 1]
            assert strategy[`r0'] == "never" & strategy[`r1'] == "always" & strategy[`rd'] == "rd"
            assert estimate[`r0'] == `P'[`k', 2] & ll[`r0'] == `P'[`k', 3] & ul[`r0'] == `P'[`k', 4]
            assert estimate[`r1'] == `P'[`k', 5] & ll[`r1'] == `P'[`k', 6] & ul[`r1'] == `P'[`k', 7]
            assert estimate[`rd'] == `P'[`k', 8] & ll[`rd'] == `P'[`k', 9] & ul[`rd'] == `P'[`k', 10]
            local t = `P'[`k', 1]
            assert label[`r0'] == "Period `t': never treated"
            assert label[`rd'] == "Period `t': risk difference"
        }
    }
    * The active frame is untouched.
    assert "`c(frame)'" == "default"
}
if _rc == 0 {
    display as result "PASS F1: frame rows equal r(predictions)"
    local ++pass_count
}
else {
    display as error "FAIL F1: frame contents (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F1"
}

**# F2: r(rd) is the (estimate ll ul p) layout effecttab from() reads
local ++test_count
capture noisily {
    msm_predict, times(2 4 9) samples(60) difference seed(4402)
    tempname P RD
    matrix `P' = r(predictions)
    matrix `RD' = r(rd)
    assert rowsof(`RD') == 3 & colsof(`RD') == 4
    assert "`: colnames `RD''" == "estimate ll ul p"
    assert "`: rownames `RD''" == "t2 t4 t9"
    forvalues k = 1/3 {
        assert `RD'[`k', 1] == `P'[`k', 8]
        assert `RD'[`k', 2] == `P'[`k', 9]
        assert `RD'[`k', 3] == `P'[`k', 10]
        assert missing(`RD'[`k', 4])
    }
    * r(rd_#) scalars still agree.
    assert r(rd_9) == `RD'[3, 1]
}
if _rc == 0 {
    display as result "PASS F2: r(rd) layout and values"
    local ++pass_count
}
else {
    display as error "FAIL F2: r(rd) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F2"
}

**# F3: survival type names the contrast r(sd) and labels it as such
local ++test_count
capture noisily {
    capture frame drop ps
    msm_predict, times(1 3) samples(40) difference seed(4403) type(survival) frame(ps)
    confirm matrix r(sd)
    capture confirm matrix r(rd)
    assert _rc != 0
    frame ps {
        assert _N == 6
        assert strategy[3] == "sd"
        assert label[3] == "Period 1: survival difference"
        assert "`: char _dta[msm_predict_type]'" == "survival"
    }
}
if _rc == 0 {
    display as result "PASS F3: survival contrast named sd"
    local ++pass_count
}
else {
    display as error "FAIL F3: survival contrast (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F3"
}

**# F4: a single strategy writes only its own rows and no contrast matrix
local ++test_count
capture noisily {
    capture frame drop pa
    msm_predict, times(1 3 5) samples(40) seed(4404) strategy(always) frame(pa)
    capture confirm matrix r(rd)
    assert _rc != 0
    frame pa {
        assert _N == 3
        assert strategy == "always"
    }
}
if _rc == 0 {
    display as result "PASS F4: single-strategy frame"
    local ++pass_count
}
else {
    display as error "FAIL F4: single-strategy frame (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F4"
}

**# F5: an existing frame needs replace; refusal happens before any work
local ++test_count
capture noisily {
    capture frame drop keepme
    frame create keepme
    frame keepme: set obs 7
    msm_predict, times(1) samples(40) seed(1)
    local before_seed = r(seed)
    capture noisily msm_predict, times(1 3) samples(40) seed(4405) frame(keepme)
    assert _rc == 110
    frame keepme: assert _N == 7
    * the earlier r() survives the refusal
    assert "`r(seed)'" == "`before_seed'"
    msm_predict, times(1 3) samples(40) seed(4405) frame(keepme, replace)
    frame keepme: assert _N == 4
}
if _rc == 0 {
    display as result "PASS F5: replace contract"
    local ++pass_count
}
else {
    display as error "FAIL F5: replace contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F5"
}

**# F6: invalid frame requests are refused with 198
local ++test_count
capture noisily {
    capture msm_predict, times(1) samples(20) frame(1bad)
    assert _rc == 198
    capture msm_predict, times(1) samples(20) frame(default)
    assert _rc == 198
    capture msm_predict, times(1) samples(20) frame(a b)
    assert _rc == 198
    capture msm_predict, times(1) samples(20) frame(ok, bogus)
    assert _rc == 198
    capture confirm frame ok
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS F6: invalid frame() refused"
    local ++pass_count
}
else {
    display as error "FAIL F6: invalid frame() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F6"
}

**# F7: a refused prediction leaves no frame behind
local ++test_count
capture noisily {
    capture frame drop never_made
    capture msm_predict, times(99) samples(20) frame(never_made)
    assert _rc == 198
    capture confirm frame never_made
    assert _rc != 0
    * a failed replace leaves the old frame in place
    capture frame drop old
    frame create old
    frame old: set obs 3
    capture msm_predict, times(99) samples(20) frame(old, replace)
    assert _rc == 198
    frame old: assert _N == 3
}
if _rc == 0 {
    display as result "PASS F7: no frame on refusal"
    local ++pass_count
}
else {
    display as error "FAIL F7: frame on refusal (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F7"
}

**# F8: signed external periods give valid r(rd) row names
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    replace period = period - 3
    quietly {
        msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity) ///
            baseline_covariates(age sex)
        msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) nolog
        msm_fit, model(logistic) outcome_cov(age sex) nolog
    }
    msm_predict, times(-2 0 3) samples(40) difference seed(4408)
    tempname RD
    matrix `RD' = r(rd)
    assert "`: rownames `RD''" == "tm2 t0 t3"
    * 1.4.12 failed here with r(101): return scalar rd_-2 is not a name.
    assert r(rd_m2) == `RD'[1, 1]
    assert r(rd_0) == `RD'[2, 1]
}
if _rc == 0 {
    display as result "PASS F8: signed-period row names"
    local ++pass_count
}
else {
    display as error "FAIL F8: signed-period row names (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F8"
}

**# Summary
if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" test_msm_predict_frame ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_predict_frame tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
