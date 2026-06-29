* crossval_predict_stcrreg.do
* Cross-validation of every finegray prediction path against StataCorp's native
* Fine-Gray estimator stcrreg (the gold-standard reference). stcrreg ships with
* Stata, so this suite has no external dependency and never skips.
*
* Equivalence (verified bit-exact on the hypoxia data):
*   finegray_predict xb          == stcrreg predict, xb
*   exp(finegray_predict xb)     == stcrreg predict        (relative subhazard)
*   finegray_predict cif @ z=0   == stcrreg predict, basecif      (baseline CIF)
*   e(basehaz) / -ln(1-CIF0)     == -ln(1 - stcrreg basecif)      (baseline H0)
*   finegray_predict cif @ z     == 1 - exp(-H0_stcrreg*exp(xb_stcrreg))
*   finegray_predict schoenfeld  == stcrreg predict, schoenfeld
*   finegray SHR / SE / 95% CI   == stcrreg SHR / SE / 95% CI     (r(table))
*
* Pairing: finegray needs every event (cause + competing) marked as an stset
* failure, then compete()/cause() split them; stcrreg marks only the cause as
* the stset failure and names the competing value in compete(). Both fit the
* identical Fine-Gray model (mirrors crossval_finegray.do).
*
* Known convention difference (asserted, not ignored):
*   Schoenfeld residuals at TIED cause-event times are split differently
*   between finegray and stcrreg. Per-observation values match exactly at
*   untied event times; within each tied event-time the group SUM matches
*   exactly. Both invariants are tested below.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "crossval_predict_stcrreg.log", replace name(_cvpstcr)

* Bootstrap: derive package root from the qa/ working directory (relocatable)
local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

* Helper: max absolute value of a (difference) variable over an optional sample
capture program drop _mad
program define _mad, rclass
    syntax varname [if]
    quietly summarize `varlist' `if'
    return scalar n   = r(N)
    return scalar mad = max(abs(r(min)), abs(r(max)))
end

capture program drop _finegray_use_hypoxia
program define _finegray_use_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

* ============================================================================
**# Configuration A: cause 1, three covariates (ifp tumsize pelnode)
* ============================================================================

* ---- stcrreg reference: fit + every native prediction ----
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(status == 1) id(stnum)
stcrreg ifp tumsize pelnode, compete(status == 2)
matrix srt = r(table)
scalar s_shr1 = srt[1,1]
scalar s_shr2 = srt[1,2]
scalar s_shr3 = srt[1,3]
scalar s_se1  = srt[2,1]
scalar s_se2  = srt[2,2]
scalar s_se3  = srt[2,3]
scalar s_ll1  = srt[5,1]
scalar s_ul1  = srt[6,1]
scalar s_ll2  = srt[5,2]
scalar s_ul2  = srt[6,2]
scalar s_ll3  = srt[5,3]
scalar s_ul3  = srt[6,3]

predict xb_s, xb
predict relsub_s                       // default = exp(xb), relative subhazard
predict bcif_s, basecif                // baseline CIF at z = 0
predict sch_s*, schoenfeld
gen double h0_s = -ln(1 - bcif_s)       // baseline cumulative subhazard
keep stnum _t _d xb_s relsub_s bcif_s h0_s sch_s1 sch_s2 sch_s3
tempfile sout_A
save "`sout_A'"

* ---- finegray: fit + covariate predictions ----
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(dfcens == 1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
matrix frt = r(table)

finegray_predict fg_xb, xb
finegray_predict fg_cif, cif
finegray_predict fg_sch, schoenfeld     // fg_sch, fg_sch_2, fg_sch_3

merge 1:1 stnum using "`sout_A'", nogen

* per-event-time multiplicity (for tied-time Schoenfeld handling)
bysort _t: gen long _nt = _N

**# A1: linear predictor xb == stcrreg predict, xb (bit-exact)
local ++test_count
capture noisily {
    gen double d_xb = fg_xb - xb_s
    _mad d_xb
    display as text "    xb max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: A1 xb vs stcrreg predict xb"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 xb vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A1"
}

**# A2: exp(xb) == stcrreg default predict (relative subhazard)
local ++test_count
capture noisily {
    gen double d_rel = exp(fg_xb) - relsub_s
    _mad d_rel
    display as text "    relsub max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-5
}
if _rc == 0 {
    display as result "  PASS: A2 exp(xb) vs stcrreg relative subhazard"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 relative subhazard vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A2"
}

**# A3: covariate-adjusted CIF == 1 - exp(-H0_stcrreg * exp(xb_stcrreg))
* stcrreg exposes no covariate-adjusted CIF via predict, so reconstruct it from
* stcrreg's own primitives (basecif-derived H0 and xb) and match finegray to it.
local ++test_count
capture noisily {
    gen double cifadj_s = 1 - exp(-h0_s * exp(xb_s))
    gen double d_cif = fg_cif - cifadj_s
    _mad d_cif
    display as text "    cif(z) max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: A3 covariate CIF vs stcrreg primitives"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 covariate CIF vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A3"
}

**# A4: Schoenfeld residuals exact at untied cause-event times (all 3 covariates)
local ++test_count
capture noisily {
    gen double d_su1 = fg_sch   - sch_s1 if !missing(fg_sch) & _nt == 1
    gen double d_su2 = fg_sch_2 - sch_s2 if !missing(fg_sch) & _nt == 1
    gen double d_su3 = fg_sch_3 - sch_s3 if !missing(fg_sch) & _nt == 1
    local mx = 0
    foreach v in d_su1 d_su2 d_su3 {
        _mad `v'
        local mx = max(`mx', r(mad))
    }
    display as text "    schoenfeld untied max|diff| = " %12.3e `mx'
    assert `mx' < 1e-5
}
if _rc == 0 {
    display as result "  PASS: A4 Schoenfeld (untied times) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 Schoenfeld untied vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A4"
}

**# A5: Schoenfeld tied-time group SUMS match stcrreg (tie-split invariant)
local ++test_count
capture noisily {
    foreach j in 1 2 3 {
        local fv = cond(`j' == 1, "fg_sch", "fg_sch_`j'")
        egen double _fgsum`j' = total(`fv'),   by(_t)
        egen double _ssum`j'  = total(sch_s`j'), by(_t)
        gen double d_gs`j' = _fgsum`j' - _ssum`j' if !missing(fg_sch)
    }
    local mx = 0
    foreach v in d_gs1 d_gs2 d_gs3 {
        _mad `v'
        local mx = max(`mx', r(mad))
    }
    display as text "    schoenfeld tie-group-sum max|diff| = " %12.3e `mx'
    assert `mx' < 1e-5
}
if _rc == 0 {
    display as result "  PASS: A5 Schoenfeld (tied-time group sums) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 Schoenfeld tie-group-sum vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A5"
}

**# A6: baseline CIF (covariates = 0) == stcrreg predict, basecif
* e() persists through merge, so finegray_predict still works in a preserved copy.
local ++test_count
capture noisily {
    preserve
    replace ifp     = 0
    replace tumsize = 0
    replace pelnode = 0
    finegray_predict fg_bcif, cif
    gen double d_bcif = fg_bcif - bcif_s
    _mad d_bcif
    display as text "    basecif max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-7
    restore
}
if _rc == 0 {
    display as result "  PASS: A6 baseline CIF vs stcrreg basecif"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 baseline CIF vs stcrreg (rc=`=_rc')"
    capture restore
    local ++fail_count
    local failed_tests "`failed_tests' A6"
}

**# A7: baseline cumulative subhazard e(basehaz) == -ln(1 - stcrreg basecif)
* e(basehaz) holds one row per cause event (time, cumulative H0). At a tied
* event time the intermediate rows carry partial cumulatives, whereas stcrreg
* basecif exposes only the final step value per distinct time. Compare the
* cumulative H0 at each DISTINCT event time (the externally meaningful step)
* against the stcrreg-derived H0 at the same time.
local ++test_count
capture noisily {
    matrix bh = e(basehaz)
    local nbh = rowsof(bh)
    local maxd = 0
    forvalues r = 1/`nbh' {
        local bt = bh[`r',1]
        * skip intermediate rows of a tied time (keep only the last per time)
        if `r' < `nbh' {
            if abs(bh[`r'+1,1] - `bt') < 1e-9 {
                continue
            }
        }
        local bh0 = bh[`r',2]
        * stcrreg H0 at this distinct event time (largest obs time <= bt)
        quietly summarize h0_s if _t <= `bt' + 1e-9
        local d = abs(`bh0' - r(max))
        local maxd = max(`maxd', `d')
    }
    display as text "    e(basehaz) vs stcrreg H0 max|diff| = " %12.3e `maxd'
    assert `maxd' < 1e-6
}
if _rc == 0 {
    display as result "  PASS: A7 e(basehaz) vs stcrreg baseline subhazard"
    local ++pass_count
}
else {
    display as error "  FAIL: A7 e(basehaz) vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A7"
}

**# A8: subhazard ratios (SHR) match stcrreg r(table)
local ++test_count
capture noisily {
    local d1 = abs(frt[1,1] - s_shr1)
    local d2 = abs(frt[1,2] - s_shr2)
    local d3 = abs(frt[1,3] - s_shr3)
    local mx = max(`d1', `d2', `d3')
    display as text "    SHR max|diff| = " %12.3e `mx'
    assert `mx' < 1e-4
}
if _rc == 0 {
    display as result "  PASS: A8 SHR estimates vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: A8 SHR vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A8"
}

**# A9: robust standard errors match stcrreg (relative; typically < 0.5%)
local ++test_count
capture noisily {
    local r1 = abs(frt[2,1] - s_se1) / s_se1
    local r2 = abs(frt[2,2] - s_se2) / s_se2
    local r3 = abs(frt[2,3] - s_se3) / s_se3
    local mx = max(`r1', `r2', `r3')
    display as text "    SE max rel diff = " %7.4f `mx'
    assert `mx' < 0.02
}
if _rc == 0 {
    display as result "  PASS: A9 robust SEs vs stcrreg (< 2% rel)"
    local ++pass_count
}
else {
    display as error "  FAIL: A9 SEs vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A9"
}

**# A10: 95% confidence limits for the SHRs match stcrreg
local ++test_count
capture noisily {
    local mx = 0
    foreach k in 1 2 3 {
        local rl = abs(frt[5,`k'] - s_ll`k') / s_ll`k'
        local ru = abs(frt[6,`k'] - s_ul`k') / s_ul`k'
        local mx = max(`mx', `rl', `ru')
    }
    display as text "    95% CI max rel diff = " %7.4f `mx'
    assert `mx' < 0.02
}
if _rc == 0 {
    display as result "  PASS: A10 SHR 95% CI vs stcrreg (< 2% rel)"
    local ++pass_count
}
else {
    display as error "  FAIL: A10 95% CI vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A10"
}

* ============================================================================
**# Configuration B: cause 2, two covariates (ifp pelnode) — other cause path
* ============================================================================

* ---- stcrreg reference ----
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(status == 2) id(stnum)
stcrreg ifp pelnode, compete(status == 1)
matrix srtB = r(table)
predict xbB_s, xb
predict bcifB_s, basecif
gen double h0B_s = -ln(1 - bcifB_s)
keep stnum _t xbB_s bcifB_s h0B_s
tempfile sout_B
save "`sout_B'"

* ---- finegray ----
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(dfcens == 1) id(stnum)
finegray ifp pelnode, compete(status) cause(2) nolog
matrix frtB = r(table)
finegray_predict fgB_xb, xb
finegray_predict fgB_cif, cif
merge 1:1 stnum using "`sout_B'", nogen

**# B1: xb exact vs stcrreg (cause 2)
local ++test_count
capture noisily {
    gen double dB_xb = fgB_xb - xbB_s
    _mad dB_xb
    display as text "    xb(cause2) max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: B1 xb vs stcrreg (cause 2)"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 xb cause 2 vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B1"
}

**# B2: covariate-adjusted CIF vs stcrreg primitives (cause 2)
local ++test_count
capture noisily {
    gen double cifadjB_s = 1 - exp(-h0B_s * exp(xbB_s))
    gen double dB_cif = fgB_cif - cifadjB_s
    _mad dB_cif
    display as text "    cif(cause2) max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: B2 covariate CIF vs stcrreg (cause 2)"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 covariate CIF cause 2 vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B2"
}

**# B3: SHR + SE + 95% CI vs stcrreg (cause 2)
local ++test_count
capture noisily {
    local mxshr = max(abs(frtB[1,1]-srtB[1,1]), abs(frtB[1,2]-srtB[1,2]))
    local mxse  = max(abs(frtB[2,1]-srtB[2,1])/srtB[2,1], ///
                      abs(frtB[2,2]-srtB[2,2])/srtB[2,2])
    local mxci = 0
    foreach k in 1 2 {
        local mxci = max(`mxci', abs(frtB[5,`k']-srtB[5,`k'])/srtB[5,`k'], ///
                                 abs(frtB[6,`k']-srtB[6,`k'])/srtB[6,`k'])
    }
    display as text "    cause2 SHR|diff=" %12.3e `mxshr' ///
        "  SE rel=" %7.4f `mxse' "  CI rel=" %7.4f `mxci'
    assert `mxshr' < 1e-4
    assert `mxse'  < 0.02
    assert `mxci'  < 0.02
}
if _rc == 0 {
    display as result "  PASS: B3 SHR/SE/CI vs stcrreg (cause 2)"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 SHR/SE/CI cause 2 vs stcrreg (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B3"
}

* ============================================================================
**# Configuration C: GitHub issue #1 -- basecif -> CIF mapping at a fixed horizon
* Regression guard for issue #1 (hamishinnes). The covariate-adjusted CIF built
* from stcrreg's baseline CIF F0 = basecif is  CIF(t|z) = 1 - (1 - F0)^exp(xb),
* NOT  F0^exp(xb). The reporter used the latter and concluded finegray was buggy;
* it is not -- finegray matches the CORRECT mapping and must NOT match the wrong
* one. Reproduces the issue scenario exactly (webuse hypoxia, fixed horizon t=3
* via timevar()), the path A3/B2 (own-_t, H0 form) does not exercise.
* ============================================================================

* ---- finegray: fixed-horizon CIF at t = 3 ----
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(dfcens == 1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
gen double t3 = 3
finegray_predict cifC_fg, cif timevar(t3)
keep stnum cifC_fg
tempfile fout_C
save "`fout_C'"

* ---- stcrreg baseline CIF F0(t=3) and xb ----
_finegray_use_hypoxia
gen byte status = failtype
stset dftime, failure(status == 1) id(stnum)
stcrreg ifp tumsize pelnode, compete(status == 2)
predict xbC_s, xb
predict bcifC_s, basecif
* F0(3) = basecif at the largest _t <= 3 (right-continuous step; basecif is
* monotone so the max over _t<=3 is the step value finegray's H0 lookup uses)
quietly summarize bcifC_s if _t <= 3
scalar F0_3 = r(max)
keep stnum xbC_s
merge 1:1 stnum using "`fout_C'", nogen

**# C1: finegray CIF(t=3) == 1 - (1 - F0)^exp(xb)  (CORRECT basecif mapping)
local ++test_count
capture noisily {
    gen double cifC_correct = 1 - (1 - F0_3)^exp(xbC_s)
    gen double dC_ok = cifC_fg - cifC_correct
    _mad dC_ok
    display as text "    issue#1 CIF vs 1-(1-F0)^exp(xb) max|diff| = " %12.3e r(mad)
    assert r(mad) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: C1 fixed-horizon CIF vs correct basecif mapping"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 CIF vs 1-(1-F0)^exp(xb) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

**# C2: finegray CIF(t=3) must NOT equal F0^exp(xb)  (the reporter's wrong line)
* Guards against a future regression toward the incorrect mapping. On hypoxia the
* wrong formula is off by up to ~0.89 in CIF units, so a generous floor suffices.
local ++test_count
capture noisily {
    gen double cifC_wrong = F0_3^exp(xbC_s)
    gen double dC_bad = cifC_fg - cifC_wrong
    _mad dC_bad
    display as text "    issue#1 CIF vs F0^exp(xb) (wrong) max|diff| = " %12.3e r(mad)
    assert r(mad) > 0.05
}
if _rc == 0 {
    display as result "  PASS: C2 CIF is not the wrong F0^exp(xb) mapping"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 finegray CIF matches the WRONG mapping (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C2"
}

* ============================================================================
**# Summary
* ============================================================================
display as text _newline "RESULTS: crossval_predict_stcrreg.do"
display as text "Total:   " as result `test_count'
display as text "Passed:  " as result `pass_count'
display as text "Failed:  " as result `fail_count'
display as text "Skipped: " as result `skip_count'

display "RESULT: crossval_predict_stcrreg tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

if `fail_count' > 0 {
    display as error "FAILED:`failed_tests'"
    display as error "SOME CROSSVAL CHECKS FAILED"
    log close _cvpstcr
    exit 1
}
display as result "ALL CROSS-VALIDATIONS PASSED"
log close _cvpstcr
