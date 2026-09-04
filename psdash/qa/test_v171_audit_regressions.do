* test_v171_audit_regressions.do -- regressions for the 2026-09-02 audit
* Usage: cd psdash/qa && stata-mp -b do test_v171_audit_regressions.do

clear all
version 16.0

capture log close _all
log using "test_v171_audit_regressions.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

global PSDASH_V171_TEST = 0
global PSDASH_V171_PASS = 0
global PSDASH_V171_FAIL = 0

capture program drop _v171_record
program define _v171_record
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global PSDASH_V171_PASS = $PSDASH_V171_PASS + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global PSDASH_V171_FAIL = $PSDASH_V171_FAIL + 1
    }
    global PSDASH_V171_TEST = $PSDASH_V171_TEST + 1
end

capture program drop _v171_multigroup_data
program define _v171_multigroup_data
    clear
    set obs 9
    gen byte arm = mod(_n - 1, 3)
    gen double x = _n
    gen double p0 = .60
    gen double p1 = .25
    gen double p2 = .15
    replace p0 = .20 if arm == 1
    replace p1 = .60 if arm == 1
    replace p2 = .20 if arm == 1
    replace p0 = .15 if arm == 2
    replace p1 = .25 if arm == 2
    replace p2 = .60 if arm == 2
    replace p0 = 0 in 1
    replace p1 = .50 in 1
    replace p2 = .50 in 1
end

**# PSDASH-01: unused auto-weights cannot hide a GPS boundary from combined
capture noisily {
    _v171_multigroup_data
    quietly psdash overlap arm, psvars(p0 p1 p2) nograph
    assert r(N) == 9
    assert r(n_gps_violate) == 1
    quietly psdash combined arm, psvars(p0 p1 p2) nobalance noweights
    assert r(N_requested) == 9
    assert r(N_analysis) == 9
    assert "`r(verdict)'" == "FAIL"
}
_v171_record `=_rc' "combined retains own-arm GPS boundary"

**# PSDASH-03: both weight modes post the documented very-extreme count
capture noisily {
    clear
    set obs 6
    gen byte trt = _n > 3
    gen double ps = .5
    gen double wt = cond(_n == 1, 5, cond(_n == 2, 15, cond(_n == 3, 25, 1)))
    quietly psdash weights trt ps, wvar(wt) extreme(10 20)
    assert r(n_extreme) == 2
    assert r(n_very_extreme) == 1

    gen byte arm = mod(_n - 1, 3)
    gen double p0 = .34
    gen double p1 = .33
    gen double p2 = .33
    quietly psdash weights arm, wvar(wt) psvars(p0 p1 p2) extreme(10 20)
    assert r(n_extreme) == 2
    assert r(n_very_extreme) == 1
}
_v171_record `=_rc' "n_very_extreme returned in both modes"

**# PSDASH-04: multigroup missing-weight exclusions are visible and boundaries fail
capture noisily {
    _v171_multigroup_data
    gen double wt = 1
    replace wt = . in 9
    quietly psdash weights arm, wvar(wt) psvars(p0 p1 p2)
    assert r(N) == 8
    assert r(n_wt_undefined) == 0
    assert r(n_wt_dropped) == 1
    assert strpos(`"`r(warnings)'"', "missing weight") > 0
    quietly psdash balance arm, covariates(x) wvar(wt) psvars(p0 p1 p2)
    assert r(N) == 8
    assert r(n_wt_undefined) == 0
    assert r(n_wt_dropped) == 1
    assert strpos(`"`r(warnings)'"', "missing weight") > 0
}
_v171_record `=_rc' "multigroup supplied-missing weight ledgers"

capture noisily {
    _v171_multigroup_data
    capture noisily psdash weights arm, psvars(p0 p1 p2)
    assert _rc == 459
    capture noisily psdash balance arm, covariates(x) psvars(p0 p1 p2)
    assert _rc == 459
}
_v171_record `=_rc' "multigroup undefined auto-weights rejected"

**# PSDASH-05: all public covariates() endpoints accept FV syntax
capture noisily {
    clear
    set obs 120
    gen byte trt = _n > 60
    gen byte cat = 1 + mod(_n, 3)
    gen double ps = .25 + .50 * trt
    quietly psdash overlap trt ps, covariates(i.cat) nograph
    quietly psdash support trt ps, covariates(i.cat) threshold(.05) compare nograph
    confirm scalar r(max_smd_pre)
    confirm scalar r(max_smd_post)
    quietly psdash detect trt ps, covariates(i.cat)
    quietly psdash combined trt ps, covariates(i.cat) nobalance noweights
}
_v171_record `=_rc' "factor variables accepted across public endpoints"

**# PSDASH-06: a requested mlogit sample missing one fitted arm fails uniformly
capture noisily {
    clear
    set seed 20260904
    set obs 180
    gen byte arm = mod(_n - 1, 3)
    gen double x = rnormal() + .2 * arm
    quietly mlogit arm x
    predict double p0 p1 p2, pr
    capture noisily psdash overlap if arm != 2, psvars(p0 p1 p2) nograph
    assert _rc == 198
    capture noisily psdash support if arm != 2, psvars(p0 p1 p2) nograph
    assert _rc == 198
    capture noisily psdash weights if arm != 2, psvars(p0 p1 p2)
    assert _rc == 198
    capture noisily psdash balance if arm != 2, covariates(x) nowvar psvars(p0 p1 p2)
    assert _rc == 198
    capture noisily psdash combined if arm != 2, psvars(p0 p1 p2) nobalance noweights
    assert _rc == 198
}
_v171_record `=_rc' "mlogit reduced-arm requests fail uniformly"

**# PSDASH-18: public detect never returns a dead temporary weight name
capture noisily {
    clear
    set seed 17118
    set obs 200
    gen double x = rnormal()
    gen byte trt = runiform() < invlogit(.4 * x)
    gen double y = trt + x + rnormal()
    quietly teffects ipw (y) (trt x), ate
    quietly psdash detect
    assert "`r(wvar)'" == "auto-generated"
    assert strpos(" `r(covariates)' ", " x ") > 0
    assert !missing(r(n_covariates))
    assert r(n_covariates) >= 1
    assert r(psvar_auto) == 1
}
_v171_record `=_rc' "detect labels temporary weight as auto-generated"

**# PSDASH-19: FV columns are constructed on the final diagnostic sample
capture noisily {
    clear
    set obs 12
    gen byte trt = _n > 6
    gen byte cat = 1 + mod(_n, 2)
    replace cat = 3 in 1
    gen double ps = .5
    replace ps = . in 1
    quietly psdash balance trt ps, covariates(i.cat) nowvar
    assert r(N) == 11
    assert strpos("`r(varlist)'", "2.cat") > 0
    assert strpos("`r(varlist)'", "3.cat") == 0
}
_v171_record `=_rc' "FV design excludes levels absent from final sample"

**# Adjacent defect: single-score K=2 mapping must check the complement arm
capture noisily {
    clear
    set obs 8
    gen byte arm = cond(_n <= 4, 3, 5)
    gen double x = _n
    gen double ps5 = .5
    replace ps5 = 1 in 1
    capture noisily psdash weights arm ps5
    assert _rc == 459
    capture noisily psdash balance arm ps5, covariates(x)
    assert _rc == 459
}
_v171_record `=_rc' "single-score non-0/1 mapping checks complementary own-arm boundary"

display as text _n "RESULT: test_v171_audit_regressions tests=$PSDASH_V171_TEST pass=$PSDASH_V171_PASS fail=$PSDASH_V171_FAIL skip=0"

local final_rc = cond($PSDASH_V171_FAIL > 0, 9, 0)
_psdash_qa_cleanup
macro drop PSDASH_V171_TEST PSDASH_V171_PASS PSDASH_V171_FAIL
capture log close _all
exit `final_rc'
