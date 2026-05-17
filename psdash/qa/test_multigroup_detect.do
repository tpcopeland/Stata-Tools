* test_multigroup_detect.do — Multi-group detection layer tests for psdash v1.2.0
* Version 1.2.0  2026/04/27

clear all

do "`c(pwd)'/_psdash_bootstrap.do"

* Test infrastructure
global n_pass_count = 0
global n_fail_count = 0
global n_test_count = 0

capture program drop _test_start
program define _test_start
    args test_num description
    global n_test_count = $n_test_count + 1
    display as text _n "--- Test `test_num': `description' ---"
end

capture program drop _test_result
program define _test_result
    args rc
    if `rc' == 0 {
        display as result "  PASS"
        global n_pass_count = $n_pass_count + 1
    }
    else {
        display as error "  FAIL (rc = `rc')"
        global n_fail_count = $n_fail_count + 1
    }
end

* =========================================================================
* SECTION 1: Binary detection backward compatibility
* =========================================================================

* Build binary test data
clear
set seed 12345
set obs 500
gen double age = rnormal(50, 10)
gen byte female = runiform() < 0.5
gen double bmi = rnormal(25, 4)
gen double ps_true = invlogit(-2 + 0.03*age + 0.5*female + 0.02*bmi)
gen byte treated = runiform() < ps_true
gen double y = 10 + 2*treated + 0.5*age + 3*female + rnormal(0, 5)
logit treated age female bmi
predict double ps, pr
gen double ipw = cond(treated==1, 1/ps, 1/(1-ps))

_test_start 1 "binary 0/1 detection sets _psd_multigroup=0"
capture {
    _psdash_detect treated ps
    assert "`_psd_multigroup'" == "0"
    assert "`_psd_K'" == "2"
    assert "`_psd_levels'" == "0 1"
    assert "`_psd_reference'" == "0"
    assert "`_psd_treatment'" == "treated"
    assert "`_psd_psvar'" == "ps"
    assert "`_psd_source'" == "manual"
}
_test_result `=_rc'

_test_start 2 "binary detection preserves legacy c_locals"
capture {
    _psdash_detect treated ps, covariates(age female bmi)
    assert "`_psd_treatment'" == "treated"
    assert "`_psd_psvar'" == "ps"
    assert "`_psd_covariates'" == "age female bmi"
    assert "`_psd_estimand'" == "ate"
}
_test_result `=_rc'

_test_start 3 "binary overlap still works after detect changes"
capture noisily {
    psdash overlap treated ps, nograph
    assert r(N) == 500
    assert r(N_treated) > 0
    assert r(N_control) > 0
}
_test_result `=_rc'

_test_start 4 "binary balance still works after detect changes"
capture {
    psdash balance treated ps, covariates(age female bmi)
    assert r(N) > 0
    assert r(max_smd_raw) >= 0
}
_test_result `=_rc'

_test_start 5 "binary weights still works after detect changes"
capture {
    psdash weights treated ps, wvar(ipw)
    assert r(ess) > 0
}
_test_result `=_rc'

* =========================================================================
* SECTION 2: Three-group detection with manual PS vars
* =========================================================================

* Build 3-group test data
preserve
clear
set seed 54321
set obs 600
gen double x1 = rnormal(0, 1)
gen double x2 = rnormal(0, 1)

* 3 treatment groups (0, 1, 2)
gen double p0 = 1
gen double p1 = exp(0.5*x1 + 0.3*x2)
gen double p2 = exp(-0.3*x1 + 0.5*x2)
gen double psum = p0 + p1 + p2
replace p0 = p0 / psum
replace p1 = p1 / psum
replace p2 = p2 / psum

gen double u = runiform()
gen byte trt3 = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))

* GPS columns (true probabilities as stand-in PS)
gen double gps0 = p0
gen double gps1 = p1
gen double gps2 = p2

_test_start 6 "3-group detection sets multigroup=1, K=3"
capture {
    _psdash_detect trt3, psvars(gps0 gps1 gps2)
    assert "`_psd_multigroup'" == "1"
    assert "`_psd_K'" == "3"
    assert "`_psd_levels'" == "0 1 2"
    assert "`_psd_reference'" == "0"
    assert "`_psd_source'" == "manual"
}
_test_result `=_rc'

_test_start 7 "3-group detection sets per-level PS c_locals"
capture {
    _psdash_detect trt3, psvars(gps0 gps1 gps2)
    assert "`_psd_ps_0'" == "gps0"
    assert "`_psd_ps_1'" == "gps1"
    assert "`_psd_ps_2'" == "gps2"
    assert "`_psd_psvar'" == "gps0"
}
_test_result `=_rc'

_test_start 8 "3-group detection errors with wrong psvars count"
capture _psdash_detect trt3, psvars(gps0 gps1)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 9 "3-group detection errors without psvars"
capture _psdash_detect trt3 gps0
_test_result `=cond(_rc == 198, 0, 1)'

* =========================================================================
* SECTION 3: Reference option
* =========================================================================

_test_start 10 "reference(1) sets reference to 1"
capture {
    _psdash_detect trt3, psvars(gps0 gps1 gps2) reference(1)
    assert "`_psd_reference'" == "1"
}
_test_result `=_rc'

_test_start 11 "reference(2) sets reference to 2"
capture {
    _psdash_detect trt3, psvars(gps0 gps1 gps2) reference(2)
    assert "`_psd_reference'" == "2"
}
_test_result `=_rc'

_test_start 12 "reference(99) errors — not a treatment level"
capture _psdash_detect trt3, psvars(gps0 gps1 gps2) reference(99)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 13 "default reference is smallest level"
capture {
    _psdash_detect trt3, psvars(gps0 gps1 gps2)
    assert "`_psd_reference'" == "0"
}
_test_result `=_rc'

* =========================================================================
* SECTION 4: Weight generation for 3-group ATE
* =========================================================================

_test_start 14 "3-group ATE weight generation via getwvar"
capture {
    capture drop _psdash_wt
    _psdash_detect trt3, psvars(gps0 gps1 gps2) getwvar estimand(ate)
    assert "`_psd_wvar'" == "_psdash_wt"
    assert "`_psd_wvar_auto'" == "1"
    confirm variable _psdash_wt

    * Verify weights: w = 1/GPS for own group
    * Group 0: w should be 1/gps0
    quietly count if trt3 == 0 & !missing(_psdash_wt)
    assert r(N) > 0
    quietly count if trt3 == 0 & abs(_psdash_wt - 1/gps0) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0

    * Group 1: w should be 1/gps1
    quietly count if trt3 == 1 & abs(_psdash_wt - 1/gps1) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0

    * Group 2: w should be 1/gps2
    quietly count if trt3 == 2 & abs(_psdash_wt - 1/gps2) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0
}
_test_result `=_rc'
capture drop _psdash_wt

_test_start 15 "3-group ATT weight generation (ref=0)"
capture {
    capture drop _psdash_wt
    _psdash_detect trt3, psvars(gps0 gps1 gps2) getwvar estimand(att)
    confirm variable _psdash_wt

    * Group 0 (reference): w = 1
    quietly count if trt3 == 0 & abs(_psdash_wt - 1) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0

    * Group 1: w = gps0/gps1
    quietly count if trt3 == 1 & abs(_psdash_wt - gps0/gps1) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0

    * Group 2: w = gps0/gps2
    quietly count if trt3 == 2 & abs(_psdash_wt - gps0/gps2) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0
}
_test_result `=_rc'
capture drop _psdash_wt

_test_start 16 "3-group ATT weight with reference(2)"
capture {
    capture drop _psdash_wt
    _psdash_detect trt3, psvars(gps0 gps1 gps2) getwvar estimand(att) reference(2)
    confirm variable _psdash_wt

    * Group 2 (reference): w = 1
    quietly count if trt3 == 2 & abs(_psdash_wt - 1) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0

    * Group 0: w = gps2/gps0
    quietly count if trt3 == 0 & abs(_psdash_wt - gps2/gps0) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0

    * Group 1: w = gps2/gps1
    quietly count if trt3 == 1 & abs(_psdash_wt - gps2/gps1) > 1e-8 & !missing(_psdash_wt)
    assert r(N) == 0
}
_test_result `=_rc'
capture drop _psdash_wt

* =========================================================================
* SECTION 5: K=2 non-0/1 detection
* =========================================================================

* Create K=2 with values 1/2
gen byte trt12 = cond(trt3 == 2, 2, 1)
gen double gps_12_1 = cond(trt12 == 1, gps0 + gps1, .)
replace gps_12_1 = cond(trt12 == 2, gps0 + gps1, gps_12_1)
* Actually, simulate proper PS for 1/2
gen double ps_1 = invlogit(0.5*x1 + 0.3*x2)
gen double ps_2 = 1 - ps_1

_test_start 17 "K=2 non-0/1 sets multigroup=1"
capture {
    _psdash_detect trt12, psvars(ps_1 ps_2)
    assert "`_psd_multigroup'" == "1"
    assert "`_psd_K'" == "2"
    assert "`_psd_levels'" == "1 2"
    assert "`_psd_reference'" == "1"
}
_test_result `=_rc'

* =========================================================================
* SECTION 6: mlogit detection
* =========================================================================

_test_start 18 "mlogit with explicit treatment uses manual path"
capture {
    mlogit trt3 x1 x2
    predict double mlps0 mlps1 mlps2, pr
    _psdash_detect trt3, psvars(mlps0 mlps1 mlps2)
    assert "`_psd_multigroup'" == "1"
    assert "`_psd_K'" == "3"
    assert "`_psd_source'" == "manual"
    * Manual path does not auto-extract covariates from e(cmdline)
    * Must pass covariates() explicitly or use auto-detect path
}
_test_result `=_rc'
capture drop mlps0 mlps1 mlps2

_test_start 19 "mlogit auto-detect from e(cmd) with psvars"
capture {
    mlogit trt3 x1 x2
    predict double mlps0 mlps1 mlps2, pr
    _psdash_detect , psvars(mlps0 mlps1 mlps2)
    assert "`_psd_treatment'" == "trt3"
    assert "`_psd_source'" == "estimation"
    assert "`_psd_multigroup'" == "1"
    assert "`_psd_K'" == "3"
}
_test_result `=_rc'
capture drop mlps0 mlps1 mlps2

_test_start 20 "mlogit without psvars errors informatively"
capture {
    mlogit trt3 x1 x2
    capture noisily _psdash_detect
    local ml_rc = _rc
    assert `ml_rc' == 198
}
_test_result `=_rc'

* =========================================================================
* SECTION 7: Binary teffects backward compat
* =========================================================================
restore

_test_start 21 "teffects binary sets multigroup=0 and all new c_locals"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipw (y) (treated age female bmi)
    _psdash_detect , samplevar() getwvar
    assert "`_psd_multigroup'" == "0"
    assert "`_psd_K'" == "2"
    assert "`_psd_levels'" == "0 1"
    assert "`_psd_reference'" == "0"
    assert "`_psd_treatment'" == "treated"
    assert "`_psd_source'" == "teffects"
}
_test_result `=_rc'
capture drop _psdash_ps
capture drop _psdash_wt

_test_start 22 "binary teffects overlap still works"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipw (y) (treated age female bmi)
    psdash overlap, nograph
    assert r(N) > 0
    assert "`r(treatment)'" == "treated"
}
_test_result `=_rc'
capture drop _psdash_ps
capture drop _psdash_wt

* =========================================================================
* SECTION 8: Edge cases
* =========================================================================

_test_start 23 "estimand flows through to detect for multi-group"
preserve
clear
set seed 11111
set obs 300
gen double x1 = rnormal(0, 1)
gen double p0 = 1
gen double p1 = exp(0.5*x1)
gen double p2 = exp(-0.3*x1)
gen double psum = p0 + p1 + p2
replace p0 = p0 / psum
replace p1 = p1 / psum
replace p2 = p2 / psum
gen double u = runiform()
gen byte trt3 = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))
gen double gps0 = p0
gen double gps1 = p1
gen double gps2 = p2
capture {
    _psdash_detect trt3, psvars(gps0 gps1 gps2) estimand(att)
    assert "`_psd_estimand'" == "att"
}
local rc23 = _rc
restore
_test_result `rc23'

_test_start 24 "all weights positive for 3-group ATE"
preserve
clear
set seed 22222
set obs 300
gen double x1 = rnormal(0, 1)
gen double p0 = 1
gen double p1 = exp(0.3*x1)
gen double p2 = exp(-0.2*x1)
gen double psum = p0 + p1 + p2
replace p0 = p0 / psum
replace p1 = p1 / psum
replace p2 = p2 / psum
gen double u = runiform()
gen byte trt3 = cond(u < p0, 0, cond(u < p0 + p1, 1, 2))
gen double gps0 = p0
gen double gps1 = p1
gen double gps2 = p2
capture {
    capture drop _psdash_wt
    _psdash_detect trt3, psvars(gps0 gps1 gps2) getwvar estimand(ate)
    quietly count if _psdash_wt <= 0 & !missing(_psdash_wt)
    assert r(N) == 0
    quietly count if missing(_psdash_wt)
    assert r(N) == 0
}
local rc24 = _rc
restore
_test_result `rc24'

* =========================================================================
* Clean up
* =========================================================================
capture drop _psdash_ps
capture drop _psdash_wt
graph close _all

* =========================================================================
* SUMMARY
* =========================================================================
display as text _n "{hline 70}"
display as text "MULTI-GROUP DETECTION TEST SUMMARY"
display as text "{hline 70}"
display as text "Tests run:    " as result %4.0f $n_test_count
display as text "Passed:       " as result %4.0f $n_pass_count
display as text "Failed:       " as result %4.0f $n_fail_count
display as text "{hline 70}"

if $n_fail_count > 0 {
    display as error "SOME TESTS FAILED"
    local suite_rc = 9
}
else {
    display as result "ALL TESTS PASSED"
    local suite_rc = 0
}

capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"
if `suite_rc' exit `suite_rc'
