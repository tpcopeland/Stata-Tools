* crossval_psdash.do — Cross-validation suite for psdash
* Tests peculiar but valid setups using known-answer synthetic datasets.
* All key quantities are computed by hand before calling psdash and
* asserted to match within tolerance.
* Version 1.1.9  2026/04/27

clear all

local _qa_plus_orig "`c(sysdir_plus)'"
local _qa_personal_orig "`c(sysdir_personal)'"
tempfile _qa_marker
local _qa_sysroot "`_qa_marker'_sysdir"
local _qa_plus "`_qa_sysroot'/plus"
local _qa_personal "`_qa_sysroot'/personal"
capture mkdir "`_qa_sysroot'"
capture mkdir "`_qa_plus'"
capture mkdir "`_qa_personal'"
sysdir set PLUS "`_qa_plus'"
sysdir set PERSONAL "`_qa_personal'"

capture ado uninstall psdash
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'"
if strpos("`pkg_dir'", "/qa") > 0 {
    local pkg_dir = subinstr("`pkg_dir'", "/qa", "", 1)
}
* Handle running from a repository root rather than this package's qa/ directory
if !strpos("`pkg_dir'", "psdash") {
    local pkg_dir "`pkg_dir'/psdash"
}
capture noisily net install psdash, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit `install_rc'
}

global cv_pass = 0
global cv_fail = 0
global cv_n    = 0

capture program drop _cv_result
program define _cv_result
    args label rc
    global cv_n = $cv_n + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global cv_pass = $cv_pass + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global cv_fail = $cv_fail + 1
    }
end

* =========================================================================
* DATASET A: Tiny exact-balance dataset (N=8, known SMD=0 by construction)
*
*   Both groups have x1={3,3,7,7} → mean=5, Var=4
*   Both groups have x2={0,0,1,1} → mean=0.5, Var=1/3
*   SMD = (mean_t - mean_c) / sqrt((Var_t + Var_c)/2) = 0 for both
*   KS  = 0 (identical distributions)
*   VR  = 1.0 for both
*   PS  = 0.5 for all → overlap_lower=0.5, overlap_upper=0.5, n_outside=0
* =========================================================================
quietly {
    clear
    set obs 8
    gen byte treated = (_n <= 4)
    gen double x1 = cond(mod(_n-1, 2)==0, 3, 7)   // {3,7,3,7} in both groups
    gen double x2 = cond(mod(_n-1, 2)==0, 0, 1)   // {0,1,0,1} in both groups
    gen double ps = 0.5
}

* CV1: SMD=0 for perfectly balanced data
display _n "--- CV Dataset A: Tiny exact-balance (N=8) ---"
capture noisily {
    psdash balance treated ps, covariates(x1 x2) nowvar
    matrix B = r(balance)
    * x1 SMD: (5-5)/sqrt((4+4)/2) = 0
    assert abs(B[1,3]) < 1e-10
    * x2 SMD: same
    assert abs(B[2,3]) < 1e-10
    * max_smd_raw = 0
    assert r(max_smd_raw) < 1e-10
    * n_imbalanced = 0
    assert r(n_imbalanced) == 0
    * N_treated = 4, N_control = 4
    assert r(N_treated) == 4
    assert r(N_control) == 4
}
_cv_result "A1: SMD=0 for perfectly balanced data" `=_rc'

* CV2: KS=0 for identical distributions
capture noisily {
    psdash balance treated ps, covariates(x1 x2) nowvar
    matrix B = r(balance)
    assert abs(B[1,5]) < 1e-10
    assert abs(B[2,5]) < 1e-10
    assert r(max_ks_raw) < 1e-10
}
_cv_result "A2: KS=0 for identical distributions" `=_rc'

* CV3: VR=1 for equal variances
capture noisily {
    psdash balance treated ps, covariates(x1 x2) nowvar
    matrix B = r(balance)
    assert abs(B[1,4] - 1) < 1e-10
    assert abs(B[2,4] - 1) < 1e-10
    assert r(n_vr_imbalanced) == 0
}
_cv_result "A3: VR=1.0 for equal variances" `=_rc'

* CV4: overlap n_outside=0 with uniform PS=0.5
capture noisily {
    psdash overlap treated ps, nograph
    assert r(n_outside) == 0
    assert abs(r(pct_outside)) < 1e-10
    assert abs(r(overlap_lower) - 0.5) < 1e-10
    assert abs(r(overlap_upper) - 0.5) < 1e-10
}
_cv_result "A4: n_outside=0 with uniform PS=0.5" `=_rc'

* CV5: support n_outside=0 with uniform PS=0.5
capture noisily {
    psdash support treated ps, nograph
    assert r(n_outside) == 0
    assert abs(r(pct_outside)) < 1e-10
}
_cv_result "A5: support n_outside=0 with uniform PS=0.5" `=_rc'

* =========================================================================
* DATASET B: Disjoint PS ranges — known 100% outside support
*
*   Treated:  PS in [0.65, 0.85] → min_ps_t=0.65, max_ps_t=0.85
*   Control:  PS in [0.10, 0.30] → min_ps_c=0.10, max_ps_c=0.30
*   overlap_lower = max(0.65, 0.10) = 0.65
*   overlap_upper = min(0.85, 0.30) = 0.30
*   upper < lower → NO common support → all N obs are "outside"
*   n_outside = N, pct_outside = 100%
* =========================================================================
quietly {
    clear
    set obs 60
    gen byte treated = (_n <= 30)
    gen double ps = .
    replace ps = 0.65 + 0.20 * (_n - 1) / 29  if treated == 1
    replace ps = 0.10 + 0.20 * (_n - 31) / 29 if treated == 0
    gen double x1 = rnormal(0,1)
    set seed 77777
    replace x1 = rnormal(0,1)
}

display _n "--- CV Dataset B: Disjoint PS ranges (N=60) ---"

* CV6: n_outside = N when PS ranges are disjoint
capture noisily {
    psdash overlap treated ps, nograph
    assert r(n_outside) == 60
    assert abs(r(pct_outside) - 100) < 0.001
    assert r(overlap_upper) < r(overlap_lower)
}
_cv_result "B6: n_outside=N when PS ranges are disjoint" `=_rc'

* CV7: support correctly reports upper < lower condition
capture noisily {
    psdash support treated ps, nograph
    assert r(n_outside) == 60
    assert r(upper_bound) < r(lower_bound)
}
_cv_result "B7: support upper_bound < lower_bound for disjoint PS" `=_rc'

* CV8: overlap_lower and upper_bound match hand calculation
capture noisily {
    psdash overlap treated ps, nograph
    * lower = max(0.65, 0.10) = 0.65
    assert abs(r(overlap_lower) - 0.65) < 1e-8
    * upper = min(0.85, 0.30) = 0.30
    assert abs(r(overlap_upper) - 0.30) < 1e-8
}
_cv_result "B8: overlap bounds match hand calculation" `=_rc'

* =========================================================================
* DATASET C: ATT with PS=0 control obs — regression test for bug fix
*
*   Bug: r(min) <= 0 error for ATT weights when PS=0 for a control
*   Fix: changed to r(min) < 0 (zero weights are valid, not negative)
*   Test: should run without error; PS=0 control gets weight=0 (not .)
* =========================================================================
quietly {
    clear
    set obs 20
    gen byte treated = (_n <= 10)
    gen double ps = .
    replace ps = 0.5 if treated == 1
    replace ps = 0.3 if treated == 0
    * Force exactly one control to have PS=0 (positivity violation)
    replace ps = 0.0 in 11
}

display _n "--- CV Dataset C: ATT with PS=0 control obs (regression bug 2) ---"

* CV9: ATT weights do NOT error when one control has PS=0
capture noisily {
    psdash weights treated ps, estimand(att)
    * min weight: control with ps=0 → 0/(1-0)=0; so min=0
    assert r(min_wt) >= 0
    * But overall ESS should still be > 0 (other obs have valid weights)
    assert r(ess) > 0
}
_cv_result "C9: ATT with PS=0 control runs without error" `=_rc'

* CV10: ATT with negative PS must error (separate check — negative PS invalid)
quietly {
    clear
    set obs 10
    gen byte treated = (_n <= 5)
    gen double ps = 0.5
    replace ps = -0.1 in 1
}
capture {
    psdash overlap treated ps, nograph
}
local rc_neg = _rc
* Restore a valid dataset for remaining tests
quietly {
    clear
    set obs 20
    gen byte treated = (_n <= 10)
    gen double ps = cond(treated==1, 0.6, 0.4)
}
if `rc_neg' == 198 {
    display as result "  PASS: C10: Negative PS still errors (rc=198)"
    global cv_pass = $cv_pass + 1
}
else {
    display as error "  FAIL: C10: Negative PS should error (rc=`rc_neg')"
    global cv_fail = $cv_fail + 1
}
global cv_n = $cv_n + 1

* =========================================================================
* DATASET D: Binary covariate — VR hand-calculation
*
*   x2 = Bernoulli in both groups
*   treated group: p_t = 0.6 → Var_t = 0.6*0.4 = 0.24
*   control group: p_c = 0.3 → Var_c = 0.3*0.7 = 0.21
*   VR = Var_t/Var_c = 0.24/0.21 ≈ 1.142857...
*   SMD = (0.6 - 0.3) / sqrt((0.24 + 0.21)/2) = 0.3 / sqrt(0.225)
*       = 0.3 / 0.474342 ≈ 0.6325
* =========================================================================
quietly {
    clear
    * 100 treated: 60 with x2=1, 40 with x2=0
    set obs 200
    gen byte treated = (_n <= 100)
    gen byte x2 = .
    replace x2 = (_n <= 60)            if treated == 1
    replace x2 = (_n - 100 <= 30)     if treated == 0
    gen double ps = cond(treated==1, 0.55, 0.45)
}

display _n "--- CV Dataset D: Binary covariate VR hand-calculation (N=200) ---"

* CV11: Binary VR matches hand calculation
capture noisily {
    * Hand calculations
    quietly summarize x2 if treated == 1
    local var_t = r(Var)
    quietly summarize x2 if treated == 0
    local var_c = r(Var)
    local vr_hand = `var_t' / `var_c'
    local sd_pooled = sqrt((`var_t' + `var_c') / 2)
    quietly summarize x2 if treated == 1
    local m_t = r(mean)
    quietly summarize x2 if treated == 0
    local m_c = r(mean)
    local smd_hand = (`m_t' - `m_c') / `sd_pooled'

    psdash balance treated ps, covariates(x2) nowvar
    matrix B = r(balance)

    assert abs(B[1,4] - `vr_hand') < 1e-8
    assert abs(B[1,3] - `smd_hand') < 1e-8
}
_cv_result "D11: Binary covariate VR and SMD match hand-calc" `=_rc'

* CV12: VR outside [0.5, 2.0] is counted correctly
capture noisily {
    * Need a dataset where some VR is outside range
    * Build: treated Var_t = 9, control Var_c = 1 → VR=9 > 2
    preserve
    clear
    set obs 20
    gen byte treated = (_n <= 10)
    gen double x_imbal = cond(treated==1, rnormal(0, 3), rnormal(0, 1))
    set seed 12345
    replace x_imbal = rnormal(0,3) if treated==1
    replace x_imbal = rnormal(0,1) if treated==0
    gen double ps_d = cond(treated==1, 0.6, 0.4)
    psdash balance treated ps_d, covariates(x_imbal) nowvar
    * VR = Var(treated)/Var(control) ≈ 9/1 = 9 → outside [0.5,2.0]
    assert r(n_vr_imbalanced) >= 1
    restore
}
_cv_result "D12: n_vr_imbalanced correctly detects high VR" `=_rc'

* =========================================================================
* DATASET E: Love plot called twice — regression test for bug fix
*
*   Bug: label define orderlab ... add accumulates old entries on 2nd call
*   Fix: cap label drop orderlab before forvalues
*   Test: 2nd call returns correct SMD values (graph labels are cosmetic,
*   but r(balance) matrix and r(max_smd_raw) must match the 2nd covariate set)
* =========================================================================
quietly {
    clear
    set seed 33333
    set obs 100
    gen byte treated = (_n <= 50)
    gen double x1 = rnormal(50, 10)
    gen double x2 = rnormal(25, 5)
    gen double x3 = rnormal(130, 20)
    gen double ps = invlogit(-1 + 0.01*x1 + 0.02*x2)
}

display _n "--- CV Dataset E: Love plot repeated calls (regression bug 3) ---"

* CV13: First loveplot call returns correct n_imbalanced
capture noisily {
    psdash balance treated ps, covariates(x1 x2) nowvar loveplot
    matrix B1 = r(balance)
    local smd_x1_call1 = B1[1,3]
    local max_smd_call1 = r(max_smd_raw)
    * Verify max_smd matches maximum of abs SMDs
    local abs1 = abs(B1[1,3])
    local abs2 = abs(B1[2,3])
    local hand_max = max(`abs1', `abs2')
    assert abs(`max_smd_call1' - `hand_max') < 1e-10
}
_cv_result "E13: First loveplot call correct r(max_smd_raw)" `=_rc'

* CV14: Second loveplot call with different covariates returns correct stats
capture noisily {
    psdash balance treated ps, covariates(x2 x3) nowvar loveplot
    matrix B2 = r(balance)
    * Verify r(balance) has x2 and x3 (not x1 from prior call)
    local rnames : rownames B2
    * rownames should be "x2 x3" not "x1 x2"
    assert "`rnames'" == "x2 x3"
    * max_smd_raw should be correctly computed for x2 x3
    local abs_x2 = abs(B2[1,3])
    local abs_x3 = abs(B2[2,3])
    local max_hand = max(`abs_x2', `abs_x3')
    assert abs(r(max_smd_raw) - `max_hand') < 1e-10
}
_cv_result "E14: Second loveplot call returns correct row names and stats" `=_rc'

* CV15: Loveplot called 3 times sequentially, each returns own stats
capture noisily {
    psdash balance treated ps, covariates(x1) nowvar loveplot
    matrix B3a = r(balance)
    psdash balance treated ps, covariates(x2) nowvar loveplot
    matrix B3b = r(balance)
    psdash balance treated ps, covariates(x3) nowvar loveplot
    matrix B3c = r(balance)
    * Each matrix should have 1 row
    assert rowsof(B3a) == 1
    assert rowsof(B3b) == 1
    assert rowsof(B3c) == 1
    * Row names should match the covariate for that call
    local rn_a : rownames B3a
    local rn_b : rownames B3b
    local rn_c : rownames B3c
    assert "`rn_a'" == "x1"
    assert "`rn_b'" == "x2"
    assert "`rn_c'" == "x3"
}
_cv_result "E15: Three sequential loveplot calls each have correct row names" `=_rc'

* =========================================================================
* DATASET F: KS hline regression — bug 4 cosmetic fix (no error check)
*   Tests that balance with ks+nowvar (narrow table) runs without error
*   and that balance with ks+wvar (wide table) also runs without error
* =========================================================================
display _n "--- CV Dataset F: KS hline combinations (regression bug 4) ---"

* CV16: balance with ks + nowvar (no-adj, ks → hline 72)
capture noisily {
    gen double ipw_e = cond(treated==1, 1/ps, 1/(1-ps))
    psdash balance treated ps, covariates(x1 x2) nowvar ks
    assert r(max_ks_raw) >= 0
    drop ipw_e
}
_cv_result "F16: balance ks+nowvar runs without error" `=_rc'

* CV17: balance with ks + wvar (adj, ks → hline 96)
capture noisily {
    gen double ipw_f = cond(treated==1, 1/ps, 1/(1-ps))
    psdash balance treated ps, covariates(x1 x2) wvar(ipw_f) ks
    assert r(max_ks_raw) >= 0
    assert !missing(r(max_smd_adj))
    drop ipw_f
}
_cv_result "F17: balance ks+wvar runs without error and has adj SMD" `=_rc'

* =========================================================================
* DATASET G: Known-answer ESS with constructed weights
*
*   All weights = 2 → ESS = (sum w)^2 / sum(w^2) = (2N)^2 / (4N) = N
*   This is a known identity: uniform weights → ESS = N
*   ESS_pct = 100%
*
*   Weights proportional to {1, 3} alternating:
*   For N=4: weights = {1, 3, 1, 3}
*   sum_w = 8, sum_w_sq = 1+9+1+9=20
*   ESS = 64/20 = 3.2
* =========================================================================
quietly {
    clear
    set obs 20
    gen byte treated = (_n <= 10)
    gen double ps = cond(treated==1, 0.6, 0.4)
    gen double wt_const = 2         // uniform → ESS = N
    gen double wt_vary = cond(mod(_n,2)==0, 3, 1)  // {1,3} alternating
}

display _n "--- CV Dataset G: Known-answer ESS with constructed weights ---"

* CV18: Constant weights → ESS = N
capture noisily {
    psdash weights treated ps, wvar(wt_const)
    assert abs(r(ess) - 20) < 0.01
    assert abs(r(ess_pct) - 100) < 0.01
    * ESS by group: treated ESS = 10, control ESS = 10
    assert abs(r(ess_treated) - 10) < 0.01
    assert abs(r(ess_control) - 10) < 0.01
}
_cv_result "G18: Constant weights → ESS=N, ESS_pct=100%" `=_rc'

* CV19: Alternating {1,3} weights — hand-verified ESS
capture noisily {
    * Overall: sum_w = 10*1 + 10*3 = ... depends on treatment
    * Treated (obs 1-10): alternating → 5 obs with wt=1 (odd), 5 obs with wt=3 (even)
    * Control (obs 11-20): alternating → wt=3 for odd (11,13,...=3), wt=1 for even
    * Actually mod(_n,2)==0 → even → wt=3
    * obs 1-10 (treated): n=1→odd→1, n=2→even→3, ..., n=9→odd→1, n=10→even→3
    * treated: 5×wt=1 + 5×wt=3 → sum_t=20, sum_sq_t=5+45=50
    * ESS_t = 400/50 = 8
    * control: n=11→odd→1, n=12→even→3, ..., n=20→even→3
    * control: 5×wt=1 + 5×wt=3 → sum_c=20, sum_sq_c=50
    * ESS_c = 400/50 = 8
    * Overall: sum_w=40, sum_sq=100, ESS=1600/100=16
    psdash weights treated ps, wvar(wt_vary)
    assert abs(r(ess) - 16) < 0.01
    assert abs(r(ess_pct) - 80) < 0.01
    assert abs(r(ess_treated) - 8) < 0.01
    assert abs(r(ess_control) - 8) < 0.01
}
_cv_result "G19: Alternating {1,3} weights → ESS=16 (hand-verified)" `=_rc'

* CV20: CV = SD/Mean hand-verified for known weights
capture noisily {
    * wt_vary: {1,3} for N=20
    quietly summarize wt_vary
    local cv_hand = r(sd) / r(mean)
    psdash weights treated ps, wvar(wt_vary)
    assert abs(r(cv) - `cv_hand') < 1e-8
}
_cv_result "G20: CV = SD/Mean hand-verified" `=_rc'

* =========================================================================
* DATASET H: Perfect separation — AUC=1.0, all obs outside support warning
*
*   PS exactly separates: treated all have PS=0.8, controls all have PS=0.2
*   Overlap region: [max(0.8,0.2), min(0.8,0.2)] = [0.8, 0.2] → inverted
*   n_outside = N, pct_outside = 100%
*   AUC: roctab with PS perfectly predicting treatment → AUC=1.0
* =========================================================================
quietly {
    clear
    set obs 40
    gen byte treated = (_n <= 20)
    gen double ps = cond(treated==1, 0.8, 0.2)
}

display _n "--- CV Dataset H: Perfect separation (N=40) ---"

* CV21: Perfect separation → pct_outside=100% and AUC=1
capture noisily {
    psdash overlap treated ps, nograph
    assert abs(r(pct_outside) - 100) < 0.001
    assert abs(r(auc) - 1) < 1e-8
    assert r(overlap_upper) < r(overlap_lower)
}
_cv_result "H21: Perfect separation → pct_outside=100%, AUC=1" `=_rc'

* CV22: Support also shows 100% outside
capture noisily {
    psdash support treated ps, nograph
    assert r(n_outside) == 40
    assert r(n_outside_treated) == 20
    assert r(n_outside_control) == 20
}
_cv_result "H22: Support correctly reports all obs outside with perfect separation" `=_rc'

* =========================================================================
* DATASET I: Weighted SMD = 0 when weights perfectly equalize means
*
*   Create treated/control with different means; construct weights so that
*   weighted means are exactly equal. Verify adj SMD = 0.
*
*   Treated: x = {10, 20} (mean=15), n=2
*   Control: x = {15, 15} (mean=15), n=2
*   Raw SMD = (15-15)/sd_pooled = 0 (also 0 here)
*
*   Better: Treated: x={10,20} mean=15; Control: x={5,25} mean=15
*   Pooled SD = sqrt((Var_t+Var_c)/2) where Var_t=50, Var_c=100 → SD=sqrt(75)
*   Raw SMD = (15-15)/sqrt(75) = 0 (still 0 — both means are 15)
*
*   Let's use asymmetric means:
*   Treated: x={12,12,12,12} mean=12
*   Control: x={8,8,8,8} mean=8
*   Both have Var=0 → sd_pooled=0 → SMD=.
*
*   Better still: use a case where weighting changes the mean to equalize.
*   Treated: x=1,2,3,4 (mean=2.5); Control: x=10,11,12,13 (mean=11.5)
*   Give control weights: w={4,3,2,1} → wmean_c = (40+33+24+13)/(4+3+2+1) = 110/10 = 11
*   (Still not 2.5)
*
*   Simplest known-answer: create dataset where IPW weights exactly balance.
*   Treated (n=2): x={0, 10}, ps={0.9, 0.1}, wt_ate=1/ps={1/0.9, 1/0.1}
*   Control (n=2): x={0, 10}, ps={0.9, 0.1}, wt_ate=1/(1-ps)={10, 10/9}
*   Treated weighted mean: (0*1/0.9 + 10*10) / (1/0.9 + 10) = (0 + 100)/(1.111+10) = 100/11.111 = 9
*   Control weighted mean: (0*10 + 10*10/9) / (10 + 10/9) = (0 + 11.11)/(10+1.11) = 11.11/11.11 = 1
*   Not balanced.
*
*   Let me use a simpler approach: directly verify that when wvar makes means equal,
*   SMD_adj=0.
*
*   Treated: x={0,10}, Control: x={5,5}
*   Raw means: T=5, C=5 → SMD_raw = 0 (both equal)
*   With any weights, SMD_adj = 0 too.
*
*   Better test: known non-zero raw SMD becomes exactly 0 after specific weights.
*   Treated: x={2,2}, Control: x={4,4} → raw means T=2, C=4
*   Pooled Var: Var_t=0, Var_c=0 → sd_pooled=0 → SMD=.
*
*   Use continuous values:
*   Treated: x={1,3} (mean=2, Var=2), Control: x={5,9} (mean=7, Var=8)
*   sd_pooled = sqrt((2+8)/2) = sqrt(5) ≈ 2.236
*   SMD_raw = (2-7)/sqrt(5) = -5/2.236 ≈ -2.236
*
*   To get adj SMD = 0, we need wmean_T = wmean_C.
*   Treated obs: wt_t1, wt_t2
*   Control obs: wt_c1, wt_c2
*   wmean_T = (1*wt_t1 + 3*wt_t2)/(wt_t1+wt_t2) = wmean_C = (5*wt_c1 + 9*wt_c2)/(wt_c1+wt_c2)
*   Set wt_t1=wt_t2=1 → wmean_T = 2
*   Set wt_c1=3, wt_c2=1 → wmean_C = (15+9)/4 = 6 (not 2)
*   Set wt_c1=9, wt_c2=1 → wmean_C = (45+9)/10 = 5.4 (not 2)
*   Set wt_c1=100, wt_c2=0 → wmean_C ≈ 5 (not 2 either)
*   The control mean can only range from 5 to 9, can never equal 2.
*
*   Let me instead use a different structure:
*   Treated: x={1,5} → mean=3, if wt={5,1} → wmean = (5+5)/6 = 10/6 ≈ 1.667
*   Control: x={3,3} → mean=3, any weights → wmean=3
*   Not going to equal.
*
*   Actually, the simplest valid test is:
*   Manually construct data where SMD_adj = 0 by setting wmean_T = wmean_C.
*   Treated: x = {a, b}, Control: x = {c, d}
*   Choose wt_T and wt_C so weighted means match.
*
*   Let's use: Treated x={2,8}, Control x={2,8} (identical distributions)
*   → SMD_raw=0, and with any weights: wmean_T = wmean_C → SMD_adj=0 too.
*
*   Actually I'll just verify the known identity: when we use ATE weights on
*   perfectly balanced data, the adjusted SMD = raw SMD = 0.
* =========================================================================
quietly {
    clear
    * 4 treated and 4 control, both with x drawn from same distribution
    set obs 8
    gen byte treated = (_n <= 4)
    gen double x = cond(_n==1, 2, cond(_n==2, 5, cond(_n==3, 8, cond(_n==4, 11, ///
                   cond(_n==5, 2, cond(_n==6, 5, cond(_n==7, 8, 11)))))))
    * Treated: {2,5,8,11}, Control: {2,5,8,11} → identical
    * ps: set to moderate values away from 0/1
    gen double ps_i = cond(treated==1, 0.6, 0.4)
    gen double wt_ate = cond(treated==1, 1/ps_i, 1/(1-ps_i))
}

display _n "--- CV Dataset I: Known-answer weighted SMD=0 ---"

* CV23: Identical distributions → raw SMD=0 and adj SMD=0
capture noisily {
    psdash balance treated ps_i, covariates(x) wvar(wt_ate)
    matrix B = r(balance)
    * Raw SMD = 0 (identical means and SDs)
    assert abs(B[1,3]) < 1e-10
    * Adj SMD = 0 (weighted means of identical distributions are still equal)
    assert abs(B[1,8]) < 1e-10
    assert r(max_smd_raw) < 1e-10
    assert r(max_smd_adj) < 1e-10
}
_cv_result "I23: Identical distributions → raw and adj SMD=0" `=_rc'

* CV24: n_treated + n_control = N invariant under weights and if conditions
capture noisily {
    psdash balance treated ps_i, covariates(x) wvar(wt_ate)
    assert r(N_treated) + r(N_control) == r(N)
    assert r(N) == 8
}
_cv_result "I24: N_treated + N_control = N invariant holds" `=_rc'

* =========================================================================
* DATASET J: Combined with selective panel suppression
* =========================================================================
quietly {
    clear
    set seed 54321
    set obs 100
    gen byte treated = runiform() < 0.5
    gen double x = rnormal(0,1)
    gen double ps = invlogit(-0.5 + 0.3*x)
}

display _n "--- CV Dataset J: Combined panel suppression ---"

* CV25: Combined with nooverlap+nobalance+noweights (support only) works
capture noisily {
    psdash combined treated ps, nooverlap nobalance noweights
    * Should still return support results via return add
    assert r(N) > 0
    assert "`r(treatment)'" == "treated"
    assert "`r(psvar)'" == "ps"
}
_cv_result "J25: Combined nooverlap+nobalance+noweights (support only) runs" `=_rc'

* CV26: Combined nooverlap+nobalance+nosupport (weights only) works
capture noisily {
    psdash combined treated ps, nooverlap nobalance nosupport
    assert r(N) > 0
    assert r(ess) > 0
}
_cv_result "J26: Combined nooverlap+nobalance+nosupport (weights only) runs" `=_rc'

* =========================================================================
* DATASET K: n_ps_boundary fires for exact PS=0 and PS=1
* =========================================================================
quietly {
    clear
    set obs 20
    gen byte treated = (_n <= 10)
    gen double ps = cond(treated==1, 0.6, 0.4)
    replace ps = 0.0 in 1    // PS=0 for treated obs
    replace ps = 1.0 in 20   // PS=1 for control obs
}

display _n "--- CV Dataset K: PS boundary detection ---"

* CV27: n_ps_boundary = 2 when exactly 2 obs have PS=0 or PS=1
capture noisily {
    psdash overlap treated ps, nograph
    assert r(n_ps_boundary) == 2
}
_cv_result "K27: n_ps_boundary=2 for 2 obs with PS=0 or 1" `=_rc'

* CV27B: balance reports boundary PS before auto-weight markout drops rows
quietly {
    clear
    set obs 8
    gen byte treated = (_n <= 4)
    gen double ps = cond(treated==1, 0.6, 0.4)
    replace ps = 0.0 in 1
    replace ps = 1.0 in 8
    gen double x = _n
}
capture noisily {
    psdash balance treated ps, covariates(x)
    assert r(n_ps_boundary) == 2
    assert r(N) == 6
    assert r(N_treated) == 3
    assert r(N_control) == 3
}
_cv_result "K27B: balance counts PS boundary before auto-weight markout" `=_rc'

* CV28: n_ps_near_boundary correctly counts PS < 0.01 or > 0.99 (excluding 0 and 1)
quietly {
    clear
    set obs 20
    gen byte treated = (_n <= 10)
    gen double ps = cond(treated==1, 0.6, 0.4)
    replace ps = 0.005 in 1   // near-boundary, not exact
    replace ps = 0.995 in 20  // near-boundary, not exact
}
capture noisily {
    psdash overlap treated ps, nograph
    assert r(n_ps_boundary) == 0
    assert r(n_ps_near_boundary) == 2
}
_cv_result "K28: n_ps_near_boundary=2 for near-boundary obs (not exact 0/1)" `=_rc'

* =========================================================================
* DATASET L: Crump with known narrow PS range → fallback or convergence check
*
*   When all PS near 0.5, inv_var = 1/(ps*(1-ps)) ≈ 4
*   LHS at alpha=0.01: 1/(0.01*0.99) ≈ 101
*   RHS at alpha=0.01: 2 * E[inv_var] ≈ 2*4 = 8
*   Since LHS >> RHS, alpha needs to be larger.
*   At alpha=0.49: LHS = 1/(0.49*0.51) ≈ 4.00, RHS ≈ 8 → still LHS < RHS
*   This means for PS all near 0.5, the Crump criterion isn't satisfied
*   for any of the grid points → fallback to alpha=0.1.
* =========================================================================
quietly {
    clear
    set seed 99999
    set obs 100
    gen byte treated = (_n <= 50)
    * PS very tightly clustered around 0.5
    gen double ps = 0.48 + 0.04 * runiform()  // ps in [0.48, 0.52]
}

display _n "--- CV Dataset L: Crump with narrow PS range ---"

* CV29: Crump with PS near 0.5 returns a valid alpha (converged or fallback)
capture noisily {
    psdash support treated ps, crump nograph
    assert r(crump_alpha) > 0
    assert r(crump_alpha) < 0.5
    assert r(trim_lower) > 0
    assert r(trim_upper) < 1
    assert r(trim_lower) == r(crump_alpha)
    assert abs(r(trim_upper) - (1 - r(crump_alpha))) < 1e-10
}
_cv_result "L29: Crump with narrow PS returns valid alpha" `=_rc'

* CV30: Threshold trimming n_trimmed verified: PS [0.48,0.52], threshold=0.45 → 0 trimmed
capture noisily {
    psdash support treated ps, threshold(0.45) nograph
    * All PS > 0.45 and < 0.55, so none trimmed
    assert r(n_trimmed) == 0
    assert abs(r(pct_trimmed)) < 0.001
}
_cv_result "L30: Threshold below PS range → n_trimmed=0" `=_rc'

* =========================================================================
* DATASET M: n_outside_treated + n_outside_control = n_outside (overlap)
*
*   Treated:  PS in [0.3, 0.7] (30 obs)
*   Control:  PS in [0.1, 0.9] (30 obs)
*   overlap_lower = max(0.3, 0.1) = 0.3
*   overlap_upper = min(0.7, 0.9) = 0.7
*   Treated outside: PS < 0.3 (none) or PS > 0.7 (none) = 0
*   Control outside: PS < 0.3 or PS > 0.7 → 20 obs (first 10 and last 10)
* =========================================================================
quietly {
    clear
    set obs 60
    gen byte treated = (_n <= 30)
    gen double ps = .
    * Treated: evenly spaced in [0.3, 0.7]
    replace ps = 0.3 + 0.4 * (_n - 1) / 29 if treated == 1
    * Control: evenly spaced in [0.1, 0.9]
    replace ps = 0.1 + 0.8 * (_n - 31) / 29 if treated == 0
    gen double x = rnormal(0, 1)
}

display _n "--- CV Dataset M: n_outside by group (N=60) ---"

* CV31: n_outside_treated + n_outside_control = n_outside
capture noisily {
    psdash overlap treated ps, nograph
    * Save r() values before subsequent commands clear them
    local n_out_M = r(n_outside)
    local lb_M = r(overlap_lower)
    local ub_M = r(overlap_upper)
    local N_t_M = r(N_treated)
    local N_c_M = r(N_control)

    * Known bounds: treated in [0.3,0.7], control in [0.1,0.9]
    assert abs(`lb_M' - 0.3) < 1e-8
    assert abs(`ub_M' - 0.7) < 1e-8
    assert `N_t_M' + `N_c_M' == 60

    * Manually count outside each group (using saved lb/ub)
    quietly count if (ps < `lb_M' | ps > `ub_M') & treated == 1
    local n_out_t_hand = r(N)
    quietly count if (ps < `lb_M' | ps > `ub_M') & treated == 0
    local n_out_c_hand = r(N)

    * Treated all within overlap region → 0 outside
    assert `n_out_t_hand' == 0
    * Decomposition must sum to total
    assert `n_out_t_hand' + `n_out_c_hand' == `n_out_M'
}
_cv_result "M31: n_outside_t + n_outside_c = n_outside" `=_rc'

* =========================================================================
* DATASET N: Combined with all four no-* flags still returns r(treatment)
* =========================================================================
quietly {
    clear
    set seed 11111
    set obs 60
    gen byte treated = runiform() < 0.5
    gen double x = rnormal(0, 1)
    gen double ps = invlogit(-0.3 + 0.5*x)
}

display _n "--- CV Dataset N: Combined all-no-* flags (N=60) ---"

* CV32: Combined nooverlap+nobalance+noweights+nosupport → r(treatment) non-empty
capture noisily {
    psdash combined treated ps, nooverlap nobalance noweights nosupport
    * With all panels suppressed, only the shared return locals are set
    assert "`r(treatment)'" == "treated"
    assert "`r(psvar)'" == "ps"
    assert "`r(estimand)'" == "ate"
}
_cv_result "N32: Combined all-no-* flags returns r(treatment)" `=_rc'

* =========================================================================
* DATASET O: max_vr_adj hand calculation (uniform weights = raw VR)
*
*   Treated (n=3): x1 = {0,2,4}, x2 = {0,2,4}
*   Control (n=3): x1 = {1,2,3}, x2 = {0,2,4}
*
*   With uniform weights wt=1, adj VR = raw VR.
*
*   x1 Var_t = [(0-2)^2+(2-2)^2+(4-2)^2]/(3-1) = (4+0+4)/2 = 4
*   x1 Var_c = [(1-2)^2+(2-2)^2+(3-2)^2]/(3-1) = (1+0+1)/2 = 1
*   VR_adj_x1 = 4/1 = 4; dev = max(|4-1|, |0.25-1|) = max(3, 0.75) = 3
*
*   x2 Var_t = 4, x2 Var_c = 4 → VR_adj_x2 = 1; dev = 0
*
*   max_vr_adj = 4 (x1 has larger deviation from 1)
* =========================================================================
quietly {
    clear
    set obs 6
    gen byte treated = (_n <= 3)
    gen double x1_O = cond(_n==1, 0, cond(_n==2, 2, cond(_n==3, 4, ///
                      cond(_n==4, 1, cond(_n==5, 2, 3)))))
    gen double x2_O = cond(_n<=3, cond(_n==1,0, cond(_n==2,2, 4)), ///
                      cond(_n==4,0, cond(_n==5,2, 4)))
    gen double ps_O = cond(treated==1, 0.6, 0.4)
    gen double wt_O = 1
}

display _n "--- CV Dataset O: max_vr_adj hand calculation (N=6) ---"

* CV33: max_vr_adj and B[1,9] match hand calculation
capture noisily {
    psdash balance treated ps_O, covariates(x1_O x2_O) wvar(wt_O)
    matrix B = r(balance)

    * x1 VR_adj = 4.0 (var_t=4, var_c=1 with uniform weights)
    assert abs(B[1,9] - 4.0) < 1e-8

    * x2 VR_adj = 1.0 (identical distributions)
    assert abs(B[2,9] - 1.0) < 1e-8

    * max_vr_adj = 4 (x1 has dev=3, x2 has dev=0)
    assert abs(r(max_vr_adj) - 4.0) < 1e-8
}
_cv_result "O33: max_vr_adj hand-verified (4.0)" `=_rc'

* =========================================================================
* DATASET P: pct_outside formula — hand-verified
*
*   N=40, 20 treated in [0.4,0.6], 20 control in [0.1,0.9]
*   overlap_lower = max(0.4, 0.1) = 0.4
*   overlap_upper = min(0.6, 0.9) = 0.6
*   Controls outside: PS < 0.4 → first 6 (step = 0.8/19 ≈ 0.0421 from 0.1):
*   c_ps = 0.1 + 0.8*i/19, outside when < 0.4: 0.1+0.8*i/19 < 0.4 → i < 7.125 → i=0..6 (7 obs)
*   Controls outside: PS > 0.6: 0.1+0.8*i/19 > 0.6 → i > 11.875 → i=12..19 (8 obs)
*   Total outside = 7 + 8 = 15 (treated all within support)
*   pct_outside = 100 * 15 / 40 = 37.5
* =========================================================================
quietly {
    clear
    set obs 40
    gen byte treated = (_n <= 20)
    gen double ps = .
    replace ps = 0.4 + 0.2 * (_n - 1) / 19 if treated == 1
    replace ps = 0.1 + 0.8 * (_n - 21) / 19 if treated == 0
}

display _n "--- CV Dataset P: pct_outside formula (N=40) ---"

* CV34: pct_outside = 100 * n_outside / N
capture noisily {
    psdash overlap treated ps, nograph
    local n_out_P = r(n_outside)
    local N_P = r(N)
    local pct_hand_P = 100 * `n_out_P' / `N_P'
    assert abs(r(pct_outside) - `pct_hand_P') < 0.001
    assert r(N) == 40
}
_cv_result "P34: pct_outside = 100*n_outside/N" `=_rc'

* CV35: pct_outside formula consistent with n_outside by group
capture noisily {
    psdash overlap treated ps, nograph
    * Save r() values before subsequent commands clear them
    local lb_P = r(overlap_lower)
    local ub_P = r(overlap_upper)
    local n_out_P = r(n_outside)

    * All treated are in [0.4, 0.6] = overlap region → 0 outside
    quietly count if (ps < `lb_P' | ps > `ub_P') & treated == 1
    local n_out_t_P = r(N)
    assert `n_out_t_P' == 0

    quietly count if (ps < `lb_P' | ps > `ub_P') & treated == 0
    local n_out_c_P = r(N)
    * n_outside = n_out_t + n_out_c (use saved local, not r())
    assert `n_out_t_P' + `n_out_c_P' == `n_out_P'
}
_cv_result "P35: n_outside decomposition treated + control = total" `=_rc'

* =========================================================================
* SUMMARY
* =========================================================================
capture drop _psdash_ps _psdash_wt
graph close _all

display ""
display "CROSS-VALIDATION SUMMARY"
display "Tests run:    " $cv_n
display "Passed:       " $cv_pass
display "Failed:       " $cv_fail

if $cv_fail > 0 {
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
