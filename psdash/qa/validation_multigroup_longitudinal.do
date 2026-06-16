* validation_multigroup_longitudinal.do - exact hand-computed checks for psdash
* multi-group balance/weights and the longitudinal (ltmle/msm/tte) per-period
* diagnostics engine. Complements validation_known_answers.do (binary, cross-
* sectional) by validating the two paths that previously had existence-only QA.
* Usage: cd psdash/qa && stata-mp -b do validation_multigroup_longitudinal.do

clear all
version 16.0
set more off

capture log close _all
log using "validation_multigroup_longitudinal.log", replace nomsg

local qa_dir "`c(pwd)'"
capture do "`qa_dir'/_psdash_bootstrap.do"
local boot_rc = _rc
if `boot_rc' {
    display as error "bootstrap failed (rc=`boot_rc')"
    exit `boot_rc'
}

global vml_n = 0
global vml_pass = 0
global vml_fail = 0

capture program drop _vml_result
program define _vml_result
    args label rc
    global vml_n = $vml_n + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global vml_pass = $vml_pass + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global vml_fail = $vml_fail + 1
    }
end

* Three-group cross-sectional fixture with known weights.
*   x1 group means: 0->2, 1->4, 2->6; sample Var = 1 in every group.
*   sd_pooled (raw) = sqrt((1+1)/2) = 1, so raw SMD = mean diff exactly.
*   w by group: 0->{1,1,2}, 1->{2,2,2}, 2->{1,3,4}.
capture program drop _vml_mg_data
program define _vml_mg_data
    clear
    set obs 9
    gen byte treat = .
    replace treat = 0 in 1/3
    replace treat = 1 in 4/6
    replace treat = 2 in 7/9
    gen double x1 = .
    replace x1 = 1 in 1
    replace x1 = 2 in 2
    replace x1 = 3 in 3
    replace x1 = 3 in 4
    replace x1 = 4 in 5
    replace x1 = 5 in 6
    replace x1 = 5 in 7
    replace x1 = 6 in 8
    replace x1 = 7 in 9
    gen double w = .
    replace w = 1 in 1
    replace w = 1 in 2
    replace w = 2 in 3
    replace w = 2 in 4
    replace w = 2 in 5
    replace w = 2 in 6
    replace w = 1 in 7
    replace w = 3 in 8
    replace w = 4 in 9
end

* Longitudinal fixture: 2 periods, binary treatment, known ps and weights.
*   Period 1: treated ps {.4,.8} w {2,4}; control ps {.2,.6} w {1,3}
*   Period 2: treated ps {.5,.9} w {2,6}; control ps {.3,.7} w {1,3}
capture program drop _vml_long_data
program define _vml_long_data
    clear
    set obs 8
    gen byte period = .
    gen byte t = .
    gen double ps = .
    gen double w = .
    * period 1
    replace period = 1 in 1/4
    replace t = 1 in 1/2
    replace t = 0 in 3/4
    replace ps = 0.4 in 1
    replace ps = 0.8 in 2
    replace ps = 0.2 in 3
    replace ps = 0.6 in 4
    replace w = 2 in 1
    replace w = 4 in 2
    replace w = 1 in 3
    replace w = 3 in 4
    * period 2
    replace period = 2 in 5/8
    replace t = 1 in 5/6
    replace t = 0 in 7/8
    replace ps = 0.5 in 5
    replace ps = 0.9 in 6
    replace ps = 0.3 in 7
    replace ps = 0.7 in 8
    replace w = 2 in 5
    replace w = 6 in 6
    replace w = 1 in 7
    replace w = 3 in 8
    gen byte touse = 1
end

display _n "=== Multi-Group / Longitudinal Manual Validation ==="

* MG1: multi-group raw balance means and SMDs are exact (reference = group 0)
capture noisily {
    _vml_mg_data
    psdash balance treat, covariates(x1) wvar(w) reference(0)
    matrix B = r(balance)

    local c_m1  = colnumb(B, "Mean_1")
    local c_m0  = colnumb(B, "Mean_0")
    local c_s10 = colnumb(B, "SMD_1v0")
    local c_v10 = colnumb(B, "VR_1v0")
    local c_m2  = colnumb(B, "Mean_2")
    local c_s20 = colnumb(B, "SMD_2v0")

    * group means: 0->2, 1->4, 2->6
    assert abs(B[1, `c_m1'] - 4) < 1e-10
    assert abs(B[1, `c_m0'] - 2) < 1e-10
    assert abs(B[1, `c_m2'] - 6) < 1e-10
    * raw SMDs with sd_pooled = 1: 1v0 = 2, 2v0 = 4
    assert abs(B[1, `c_s10'] - 2) < 1e-10
    assert abs(B[1, `c_s20'] - 4) < 1e-10
    * variance ratio 1v0 = 1/1 = 1
    assert abs(B[1, `c_v10'] - 1) < 1e-10

    assert r(K) == 3
    assert r(N) == 9
    assert r(N_group_0) == 3
    assert r(N_group_1) == 3
    assert r(N_group_2) == 3
    assert abs(r(max_smd_raw) - 4) < 1e-10
    assert "`r(reference)'" == "0"
}
_vml_result "MG1 multi-group raw means/SMD exact" `=_rc'

* MG2: multi-group weighted (adjusted) means and SMDs are exact
capture noisily {
    _vml_mg_data
    psdash balance treat, covariates(x1) wvar(w) reference(0)
    matrix B = r(balance)

    local c_ma1 = colnumb(B, "MnAdj_1")
    local c_ma0 = colnumb(B, "MnAdj_0")
    local c_ma2 = colnumb(B, "MnAdj_2")
    local c_sa1 = colnumb(B, "SMDAdj_1v0")
    local c_sa2 = colnumb(B, "SMDAdj_2v0")

    * weighted means: 0->(1*1+1*2+2*3)/4=2.25; 1->24/6=4; 2->(5+18+28)/8=6.375
    assert abs(B[1, `c_ma0'] - 2.25) < 1e-10
    assert abs(B[1, `c_ma1'] - 4) < 1e-10
    assert abs(B[1, `c_ma2'] - 6.375) < 1e-10
    * adjusted SMD uses raw sd_pooled (=1): 1v0=(4-2.25)=1.75; 2v0=(6.375-2.25)=4.125
    assert abs(B[1, `c_sa1'] - 1.75) < 1e-10
    assert abs(B[1, `c_sa2'] - 4.125) < 1e-10
    assert abs(r(max_smd_adj) - 4.125) < 1e-10
}
_vml_result "MG2 multi-group weighted means/SMD exact" `=_rc'

* MG3: multi-group weight ESS decomposition is exact overall and per group
capture noisily {
    _vml_mg_data
    psdash weights treat, wvar(w)

    * overall: sum=18 sumsq=44 ESS=324/44; mean=2
    assert r(N) == 9
    assert r(K) == 3
    assert abs(r(mean_wt) - 2) < 1e-10
    assert abs(r(ess) - (324 / 44)) < 1e-10
    assert abs(r(ess_pct) - (100 * (324 / 44) / 9)) < 1e-8
    * group 0: sum=4 sumsq=6 ESS=16/6
    assert abs(r(ess_group_0) - (16 / 6)) < 1e-10
    assert abs(r(ess_pct_group_0) - (100 * (16 / 6) / 3)) < 1e-8
    * group 1: sum=6 sumsq=12 ESS=3
    assert abs(r(ess_group_1) - 3) < 1e-10
    * group 2: sum=8 sumsq=26 ESS=64/26
    assert abs(r(ess_group_2) - (64 / 26)) < 1e-10
}
_vml_result "MG3 multi-group weight ESS exact by group" `=_rc'

* LONG1: longitudinal per-period overlap matrix is exact row by row
capture noisily {
    _vml_long_data
    _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    matrix OV = r(overlap_by_period)

    local c_N  = colnumb(OV, "N")
    local c_Nt = colnumb(OV, "N_treated")
    local c_Nc = colnumb(OV, "N_control")
    local c_mt = colnumb(OV, "mean_treated")
    local c_mc = colnumb(OV, "mean_control")
    local c_lo = colnumb(OV, "overlap_lower")
    local c_up = colnumb(OV, "overlap_upper")
    local c_po = colnumb(OV, "pct_outside")

    * period 1: mean_t=.6 mean_c=.4 lower=max(.4,.2)=.4 upper=min(.8,.6)=.6; 2/4 outside
    assert OV[1, `c_N']  == 4
    assert OV[1, `c_Nt'] == 2
    assert OV[1, `c_Nc'] == 2
    assert abs(OV[1, `c_mt'] - 0.6) < 1e-10
    assert abs(OV[1, `c_mc'] - 0.4) < 1e-10
    assert abs(OV[1, `c_lo'] - 0.4) < 1e-10
    assert abs(OV[1, `c_up'] - 0.6) < 1e-10
    assert abs(OV[1, `c_po'] - 50) < 1e-8
    * period 2: mean_t=.7 mean_c=.5 lower=max(.5,.3)=.5 upper=min(.9,.7)=.7; 2/4 outside
    assert OV[2, `c_N']  == 4
    assert abs(OV[2, `c_mt'] - 0.7) < 1e-10
    assert abs(OV[2, `c_mc'] - 0.5) < 1e-10
    assert abs(OV[2, `c_lo'] - 0.5) < 1e-10
    assert abs(OV[2, `c_up'] - 0.7) < 1e-10
    assert abs(OV[2, `c_po'] - 50) < 1e-8
}
_vml_result "LONG1 per-period overlap matrix exact" `=_rc'

* LONG2: longitudinal per-period weight matrix is exact (N, mean, max, ESS%)
capture noisily {
    _vml_long_data
    _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    matrix WP = r(weights_by_period)

    local c_N   = colnumb(WP, "N")
    local c_mn  = colnumb(WP, "mean")
    local c_mx  = colnumb(WP, "max")
    local c_ess = colnumb(WP, "ess_pct")

    * period 1: w={2,4,1,3} sum=10 sumsq=30 mean=2.5 max=4 ESS%=100*(100/30)/4
    assert WP[1, `c_N'] == 4
    assert abs(WP[1, `c_mn'] - 2.5) < 1e-10
    assert abs(WP[1, `c_mx'] - 4) < 1e-10
    assert abs(WP[1, `c_ess'] - (100 * (100 / 30) / 4)) < 1e-8
    * period 2: w={2,6,1,3} sum=12 sumsq=50 mean=3 max=6 ESS%=100*(144/50)/4
    assert WP[2, `c_N'] == 4
    assert abs(WP[2, `c_mn'] - 3) < 1e-10
    assert abs(WP[2, `c_mx'] - 6) < 1e-10
    assert abs(WP[2, `c_ess'] - (100 * (144 / 50) / 4)) < 1e-8
}
_vml_result "LONG2 per-period weight matrix exact" `=_rc'

* LONG3: longitudinal overall scalar summary is exact
capture noisily {
    _vml_long_data
    _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)

    * overall w={2,4,1,3,2,6,1,3} sum=22 sumsq=80 mean=2.75 ESS=484/80
    assert r(N) == 8
    assert r(N_periods) == 2
    assert abs(r(mean_wt) - 2.75) < 1e-10
    assert abs(r(min_wt) - 1) < 1e-10
    assert abs(r(max_wt) - 6) < 1e-10
    assert abs(r(ess) - (484 / 80)) < 1e-10
    assert abs(r(ess_pct) - (100 * (484 / 80) / 8)) < 1e-8
    * both periods have 50% outside common support
    assert abs(r(max_pct_outside) - 50) < 1e-8
    assert r(longitudinal) == 1
}
_vml_result "LONG3 longitudinal overall summary exact" `=_rc'

* LONG4: degenerate single-period-overlap case yields no-common-support flag
capture noisily {
    _vml_long_data
    * Shift period 2 treated entirely above control: treated ps {.85,.95}, control {.2,.4}
    replace ps = 0.85 in 5
    replace ps = 0.95 in 6
    replace ps = 0.2 in 7
    replace ps = 0.4 in 8
    _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    matrix OV = r(overlap_by_period)
    local c_lo = colnumb(OV, "overlap_lower")
    local c_up = colnumb(OV, "overlap_upper")
    local c_po = colnumb(OV, "pct_outside")
    * period 2: lower=max(.85,.2)=.85 upper=min(.95,.4)=.4 -> inverted -> 100% outside
    assert abs(OV[2, `c_lo'] - 0.85) < 1e-10
    assert abs(OV[2, `c_up'] - 0.4) < 1e-10
    assert abs(OV[2, `c_po'] - 100) < 1e-8
    assert abs(r(max_pct_outside) - 100) < 1e-8
}
_vml_result "LONG4 no-common-support period exact" `=_rc'

display ""
display "MULTI-GROUP / LONGITUDINAL VALIDATION SUMMARY"
display "Tests run:    " $vml_n
display "Passed:       " $vml_pass
display "Failed:       " $vml_fail
display "RESULT: validation_multigroup_longitudinal tests=" $vml_n " pass=" $vml_pass " fail=" $vml_fail

if $vml_fail > 0 {
    display as error "SOME TESTS FAILED"
    local suite_rc = 9
}
else {
    display as result "ALL TESTS PASSED"
    local suite_rc = 0
}

_psdash_qa_cleanup
capture log close _all
if `suite_rc' exit `suite_rc'
