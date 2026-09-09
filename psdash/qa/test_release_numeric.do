* test_release_numeric.do -- numerical-stability and missing-option regressions
* Usage: cd psdash/qa && stata-mp -b do test_release_numeric.do

clear all
version 16.0

capture log close _all
log using "test_release_numeric.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

global PSDASH_NUM_TEST = 0
global PSDASH_NUM_PASS = 0
global PSDASH_NUM_FAIL = 0

capture program drop _psdash_num_record
program define _psdash_num_record
    args rc label
    global PSDASH_NUM_TEST = $PSDASH_NUM_TEST + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global PSDASH_NUM_PASS = $PSDASH_NUM_PASS + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global PSDASH_NUM_FAIL = $PSDASH_NUM_FAIL + 1
    }
end

capture program drop _psdash_num_data
program define _psdash_num_data
    clear
    set obs 4
    gen byte treat = _n <= 2
    gen double ps = cond(treat, .4, .6)
    gen double x = _n
end

* ESS=(1+2+1+2)^2/(1^2+2^2+1^2+2^2)=3.6 and CV=sqrt(1/3)/1.5.
* Multiplying every weight by 1e200 or 1e-200 cannot change either quantity.
capture noisily {
    _psdash_num_data
    gen double whi = cond(inlist(_n, 1, 3), 1e200, 2e200)
    gen double wlo = cond(inlist(_n, 1, 3), 1e-200, 2e-200)
    local ess_expected = 3.6
    local cv_expected = sqrt(1/3) / 1.5

    foreach w in whi wlo {
        quietly psdash weights treat ps, wvar(`w')
        assert abs(r(ess) - `ess_expected') < 1e-12
        assert abs(r(cv) - `cv_expected') < 1e-12
        assert abs(r(sd_wt) / r(mean_wt) - `cv_expected') < 1e-12
        assert abs(r(ess_treated) - 1.8) < 1e-12
        assert abs(r(ess_control) - 1.8) < 1e-12
    }
}
_psdash_num_record `=_rc' "scale-invariant weight ESS and CV remain finite"

* Overall scaling cannot be reused for arm diagnostics: these two arms differ
* by 400 orders of magnitude but have the same within-arm ESS of 1.8.
capture noisily {
    _psdash_num_data
    gen double w_mixed = cond(treat, cond(_n == 1, 1e200, 2e200), ///
        cond(_n == 3, 1e-200, 2e-200))
    quietly psdash weights treat ps, wvar(w_mixed)
    assert abs(r(ess_treated) - 1.8) < 1e-12
    assert abs(r(ess_control) - 1.8) < 1e-12

    clear
    set obs 6
    gen byte arm = mod(_n - 1, 3)
    gen double p0 = 1/3
    gen double p1 = 1/3
    gen double p2 = 1/3
    gen double w_multi = cond(arm == 0, cond(_n == 1, 1e200, 2e200), ///
        cond(arm == 1, cond(_n == 2, 1e-200, 2e-200), ///
        cond(_n == 3, 1, 2)))
    quietly psdash weights arm, wvar(w_multi) psvars(p0 p1 p2)
    foreach lev of numlist 0/2 {
        assert abs(r(ess_group_`lev') - 1.8) < 1e-12
    }
}
_psdash_num_record `=_rc' "arm-specific scaling preserves ESS across exponent ranges"

* Longitudinal diagnostics call the helper once per period, including periods
* with one observed arm. Such a period has one valid arm ESS and one missing
* arm ESS; it must not turn the warning path into an error.
capture noisily {
    clear
    set obs 2
    gen byte treat = 1
    gen byte touse = 1
    gen double w_single = cond(_n == 1, 1e200, 2e200)
    _psdash_weights_stats, wvar(w_single) treatment(treat) samplevar(touse) n(2)
    assert r(n_treated) == 2
    assert r(n_control) == 0
    assert abs(r(ess_t) - 1.8) < 1e-12
    assert missing(r(ess_c))
}
_psdash_num_record `=_rc' "single-arm helper call retains missing absent-arm ESS"

* The modification helper uses the same normalized calculation; nonbinding caps
* must preserve the scale-invariant diagnostics at both exponent extremes.
capture noisily {
    _psdash_num_data
    gen double whi = cond(inlist(_n, 1, 3), 1e200, 2e200)
    gen double wlo = cond(inlist(_n, 1, 3), 1e-200, 2e-200)
    local cv_expected = sqrt(1/3) / 1.5

    quietly psdash weights treat ps, wvar(whi) truncate(1e250) generate(whi_cap)
    assert abs(r(new_ess) - 3.6) < 1e-12
    assert abs(r(new_cv) - `cv_expected') < 1e-12
    assert whi_cap == whi

    quietly psdash weights treat ps, wvar(wlo) truncate(1e-150) generate(wlo_cap)
    assert abs(r(new_ess) - 3.6) < 1e-12
    assert abs(r(new_cv) - `cv_expected') < 1e-12
    assert wlo_cap == wlo
}
_psdash_num_record `=_rc' "modified-weight ESS and CV remain finite"

* A missing threshold is not a positive threshold: it previously made a visibly
* imbalanced balance table report "Balanced" at rc=0.
capture noisily {
    _psdash_num_data
    capture noisily psdash balance treat ps, covariates(x) threshold(.)
    assert _rc == 198

    capture noisily psdash weights treat ps, truncate(.) generate(w_bad)
    assert _rc == 198
}
_psdash_num_record `=_rc' "missing numeric options are rejected"

display as text _n "RESULT: test_release_numeric tests=$PSDASH_NUM_TEST pass=$PSDASH_NUM_PASS fail=$PSDASH_NUM_FAIL skip=0"

local final_rc = cond($PSDASH_NUM_FAIL > 0, 9, 0)
_psdash_qa_cleanup
macro drop PSDASH_NUM_TEST PSDASH_NUM_PASS PSDASH_NUM_FAIL
capture log close _all
exit `final_rc'
