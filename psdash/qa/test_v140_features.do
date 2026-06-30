* test_v140_features.do — QA for psdash v1.4.0 methodological hardening
* Covers: weighted KS (WKS), binary-covariate VR exclusion + vrbounds (VRB),
*         configurable extreme() + max_ratio (EXT), stabilize precondition note
*         (STAB), quantile common support qtrim() (QT), Crump refinement (CR),
*         and help-file documentation of the new options (DOC).
* Usage: cd psdash/qa && stata-mp -b do test_v140_features.do

clear all
version 16.0
set more off

capture log close _all
log using "test_v140_features.log", replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

* Isolated install of the local copy
capture do "`qa_dir'/_psdash_bootstrap.do"

global N_PASS = 0
global N_FAIL = 0
global FAILED ""

capture program drop _t
program define _t
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global N_PASS = $N_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global N_FAIL = $N_FAIL + 1
        global FAILED "$FAILED `id'"
    }
end

* Independent weighted-KS reference (weighted empirical CDF, group a vs b)
capture program drop _ref_wks
program define _ref_wks, rclass
    args var trt wt a b
    preserve
    quietly keep if !missing(`var')
    quietly summarize `wt' if `trt' == `a'
    local Wa = r(sum)
    quietly summarize `wt' if `trt' == `b'
    local Wb = r(sum)
    sort `var'
    quietly gen double _cfa = sum(cond(`trt' == `a', `wt', 0)) / `Wa'
    quietly gen double _cfb = sum(cond(`trt' == `b', `wt', 0)) / `Wb'
    quietly by `var': gen byte _lst = (_n == _N)
    quietly gen double _dd = abs(_cfa - _cfb) if _lst
    quietly summarize _dd
    return scalar ksw = r(max)
    restore
end

* ---- Fixture: binary treatment with one binary covariate ----
sysuse auto, clear
gen byte rep_hi = rep78 >= 4 if !missing(rep78)
qui logit foreign mpg weight rep_hi
predict double ps, pr
gen double ipw = cond(foreign == 1, 1/ps, 1/(1-ps)) if !missing(ps)

**# WKS1 — weighted KS computed and matches weighted empirical CDF
display as text _n "--- WKS1: KS_Adj equals weighted empirical-CDF KS ---"
capture noisily {
    psdash balance foreign ps, covariates(mpg weight) ks
    matrix B = r(balance)
    assert !missing(B[1, 10]) & !missing(B[2, 10])
    _ref_wks mpg foreign ipw 1 0
    assert abs(B[1, 10] - r(ksw)) < 1e-9
    _ref_wks weight foreign ipw 1 0
    assert abs(B[2, 10] - r(ksw)) < 1e-9
    psdash balance foreign ps, covariates(mpg weight) ks
    assert abs(r(max_ks_adj) - max(B[1,10], B[2,10])) < 1e-9
}
_t "WKS1_weighted_ks" `=_rc'

**# WKS2 — KS_Adj missing when no weights (nowvar)
display as text _n "--- WKS2: KS_Adj missing under nowvar (raw only) ---"
capture noisily {
    psdash balance foreign ps, covariates(mpg weight) nowvar ks
    matrix B = r(balance)
    assert missing(B[1, 10])
    assert r(max_ks_adj) == . | "`=r(max_ks_adj)'" == ""
}
_t "WKS2_nowvar_missing" `=_rc'

**# VRB1 — binary covariate excluded from the VR count + footnoted
display as text _n "--- VRB1: binary covariate excluded from VR verdict ---"
capture noisily {
    psdash balance foreign ps, covariates(mpg weight rep_hi)
    assert r(n_binary_vr) == 1
    assert "`r(vr_na_vars)'" == "rep_hi"
    * rep_hi must not contribute to the VR imbalance count
    local nvr_with = r(n_vr_imbalanced)
    psdash balance foreign ps, covariates(mpg weight)
    assert r(n_binary_vr) == 0
    assert "`r(vr_na_vars)'" == ""
}
_t "VRB1_binary_vr_excluded" `=_rc'

**# VRB2 — vrbounds() changes the VR imbalance count
display as text _n "--- VRB2: vrbounds() controls the VR imbalance count ---"
capture noisily {
    psdash balance foreign ps, covariates(mpg weight) vrbounds(0.5 2.0)
    local nvr_wide = r(n_vr_imbalanced)
    psdash balance foreign ps, covariates(mpg weight) vrbounds(0.9 1.1)
    local nvr_tight = r(n_vr_imbalanced)
    assert `nvr_tight' >= `nvr_wide'
}
_t "VRB2_vrbounds_option" `=_rc'

**# EXT1 — extreme() cutoffs + scale-free max_ratio
display as text _n "--- EXT1: extreme() cutoffs and r(max_ratio) ---"
capture noisily {
    psdash weights foreign ps
    local ratio_def = r(max_ratio)
    local nx_def = r(n_extreme)
    assert r(extreme_hi) == 10 & r(extreme_vhi) == 20
    * max_ratio = max/mean, scale-free
    assert abs(`ratio_def' - r(max_wt)/r(mean_wt)) < 1e-9
    psdash weights foreign ps, extreme(3 6)
    assert r(extreme_hi) == 3 & r(extreme_vhi) == 6
    assert r(n_extreme) >= `nx_def'
    * rescaling weights leaves max_ratio invariant
    gen double ipw2 = 100 * ipw
    psdash weights foreign ps, wvar(ipw2)
    assert abs(r(max_ratio) - `ratio_def') < 1e-6
}
_t "EXT1_extreme_maxratio" `=_rc'

**# STAB1 — stabilize note path with user-supplied weights still runs
display as text _n "--- STAB1: stabilize with user wvar runs (precondition note) ---"
capture noisily {
    capture drop wstab
    psdash weights foreign ps, wvar(ipw) stabilize generate(wstab)
    assert !missing(r(mean_wt))
    confirm variable wstab
}
_t "STAB1_stabilize_userwvar" `=_rc'

**# QT1 — qtrim() quantile common support vs min-max
display as text _n "--- QT1: qtrim() narrows the optimistic min-max support ---"
capture noisily {
    psdash support foreign ps, nograph
    local lb_mm = r(lower_bound)
    local ub_mm = r(upper_bound)
    psdash support foreign ps, qtrim(5) nograph
    assert r(qtrim) == 5
    * quantile region is contained within the min-max region
    assert r(lower_bound) >= `lb_mm' - 1e-12
    assert r(upper_bound) <= `ub_mm' + 1e-12
}
_t "QT1_qtrim_support" `=_rc'

**# QT2 — qtrim() input validation and multigroup rejection
display as text _n "--- QT2: qtrim() range + multigroup rejection ---"
capture noisily {
    capture psdash support foreign ps, qtrim(60) nograph
    assert _rc == 198
    capture psdash support foreign ps, qtrim(0) nograph
    assert _rc == 198
}
_t "QT2_qtrim_validation" `=_rc'

**# CR1 — Crump optimal alpha is valid and symmetric (refined grid)
display as text _n "--- CR1: Crump alpha valid, symmetric trim region ---"
capture noisily {
    psdash support foreign ps, crump nograph
    local ca = r(crump_alpha)
    assert `ca' > 0 & `ca' < 0.5
    assert abs(r(trim_lower) - `ca') < 1e-12
    assert abs(r(trim_upper) - (1 - `ca')) < 1e-12
}
_t "CR1_crump_alpha" `=_rc'

**# DOC1 — help documents the new options and returns
display as text _n "--- DOC1: sthlp documents v1.4.0 options/returns ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "vrb:ounds") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "ext:reme") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "qtrim(#)") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "max_ks_adj") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "max_ratio") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "weighted empirical CDF") > 0
}
_t "DOC1_help_options" `=_rc'

**# Summary
display as text _n "=== v1.4.0 FEATURE TESTS: $N_PASS passed, $N_FAIL failed ==="
capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 {
    display as error "FAILED:$FAILED"
    exit 9
}
