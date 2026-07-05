* validation_known_answers.do - exact hand-computed checks for psdash
* Usage: cd psdash/qa && stata-mp -b do validation_known_answers.do

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

global vka_n = 0
global vka_pass = 0
global vka_fail = 0

capture program drop _vka_result
program define _vka_result
    args label rc
    global vka_n = $vka_n + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global vka_pass = $vka_pass + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global vka_fail = $vka_fail + 1
    }
end

capture program drop _vka_exact_data
program define _vka_exact_data
    clear
    set obs 6
    gen byte treated = (_n <= 3)

    gen double ps = .
    replace ps = 0.25 in 1
    replace ps = 0.50 in 2
    replace ps = 0.80 in 3
    replace ps = 0.10 in 4
    replace ps = 0.40 in 5
    replace ps = 0.70 in 6

    gen double x1 = .
    replace x1 = 2 in 1
    replace x1 = 4 in 2
    replace x1 = 6 in 3
    replace x1 = 1 in 4
    replace x1 = 3 in 5
    replace x1 = 5 in 6

    gen double x2 = .
    replace x2 = 0 in 1
    replace x2 = 0 in 2
    replace x2 = 1 in 3
    replace x2 = 0 in 4
    replace x2 = 1 in 5
    replace x2 = 1 in 6

    gen double wt = .
    replace wt = 1 in 1
    replace wt = 1 in 2
    replace wt = 4 in 3
    replace wt = 1 in 4
    replace wt = 1 in 5
    replace wt = 1 in 6
end

display _n "=== Exact Known-Answer Validation ==="

* KA1: raw and weighted balance matrix values match hand calculations
capture noisily {
    _vka_exact_data
    psdash balance treated ps, covariates(x1 x2) wvar(wt)
    matrix B = r(balance)

    * x1: T={2,4,6}, C={1,3,5}; means 4 and 3; Var=4 in both groups.
    assert abs(B[1,1] - 4) < 1e-10
    assert abs(B[1,2] - 3) < 1e-10
    assert abs(B[1,3] - 0.5) < 1e-10
    assert abs(B[1,4] - 1) < 1e-10
    assert abs(B[1,5] - (1/3)) < 1e-10

    * x1 adjusted: treated weighted mean=(2+4+24)/6=5; control=3.
    assert abs(B[1,6] - 5) < 1e-10
    assert abs(B[1,7] - 3) < 1e-10
    assert abs(B[1,8] - 1) < 1e-10

    * x2: means 1/3 and 2/3; sample variances both 1/3.
    assert abs(B[2,1] - (1/3)) < 1e-10
    assert abs(B[2,2] - (2/3)) < 1e-10
    assert abs(B[2,3] - (-1/sqrt(3))) < 1e-10
    assert abs(B[2,4] - 1) < 1e-10
    assert abs(B[2,5] - (1/3)) < 1e-10

    * x2 adjusted: treated weighted mean=4/6=2/3; control=2/3.
    assert abs(B[2,6] - (2/3)) < 1e-10
    assert abs(B[2,7] - (2/3)) < 1e-10
    assert abs(B[2,8]) < 1e-10

    assert abs(r(max_smd_raw) - (1/sqrt(3))) < 1e-10
    assert abs(r(max_smd_adj) - 1) < 1e-10
    assert r(n_imbalanced) == 1
}
_vka_result "KA1 balance matrix exact raw/weighted values" `=_rc'

* KA2: overlap bounds, outside count, pct, and AUC are exact
capture noisily {
    _vka_exact_data
    psdash overlap treated ps, nograph

    assert r(N) == 6
    assert r(N_treated) == 3
    assert r(N_control) == 3
    assert abs(r(mean_ps_treated) - ((0.25 + 0.50 + 0.80) / 3)) < 1e-10
    assert abs(r(mean_ps_control) - ((0.10 + 0.40 + 0.70) / 3)) < 1e-10
    assert abs(r(overlap_lower) - 0.25) < 1e-10
    assert abs(r(overlap_upper) - 0.70) < 1e-10
    assert r(n_outside) == 2
    assert abs(r(pct_outside) - (100 * 2 / 6)) < 1e-8
    assert abs(r(auc) - (6 / 9)) < 1e-10
}
_vka_result "KA2 overlap exact support and AUC" `=_rc'

* KA3: support common-region counts and generated indicator are exact
capture noisily {
    _vka_exact_data
    psdash support treated ps, generate(in_support) replace nograph

    assert abs(r(lower_bound) - 0.25) < 1e-10
    assert abs(r(upper_bound) - 0.70) < 1e-10
    assert r(n_outside) == 2
    assert r(n_outside_treated) == 1
    assert r(n_outside_control) == 1
    assert in_support[1] == 1
    assert in_support[2] == 1
    assert in_support[3] == 0
    assert in_support[4] == 0
    assert in_support[5] == 1
    assert in_support[6] == 1
}
_vka_result "KA3 support generated indicator exact by row" `=_rc'

* KA4: manual threshold trimming uses inclusive bounds
capture noisily {
    _vka_exact_data
    psdash support treated ps, threshold(0.25) generate(in_trim) replace nograph

    assert abs(r(trim_lower) - 0.25) < 1e-10
    assert abs(r(trim_upper) - 0.75) < 1e-10
    assert r(n_trimmed) == 2
    assert abs(r(pct_trimmed) - (100 * 2 / 6)) < 1e-8
    assert in_trim[1] == 1
    assert in_trim[2] == 1
    assert in_trim[3] == 0
    assert in_trim[4] == 0
    assert in_trim[5] == 1
    assert in_trim[6] == 1
}
_vka_result "KA4 threshold trimming exact inclusive bounds" `=_rc'

* KA5: explicit constructed weights produce exact ESS decomposition
capture noisily {
    _vka_exact_data
    psdash weights treated ps, wvar(wt)

    * wt={1,1,4,1,1,1}; sum=9, sumsq=21, ESS=81/21.
    assert abs(r(mean_wt) - 1.5) < 1e-10
    assert abs(r(min_wt) - 1) < 1e-10
    assert abs(r(max_wt) - 4) < 1e-10
    assert abs(r(ess) - (81 / 21)) < 1e-10
    assert abs(r(ess_pct) - (100 * (81 / 21) / 6)) < 1e-8
    assert abs(r(ess_treated) - 2) < 1e-10
    assert abs(r(ess_control) - 3) < 1e-10
    assert r(n_extreme) == 0
}
_vka_result "KA5 explicit weight ESS exact overall and by group" `=_rc'

* KA6: ATE auto-weight formulas match exact hand calculations
capture noisily {
    _vka_exact_data
    local w1 = 1 / 0.25
    local w2 = 1 / 0.50
    local w3 = 1 / 0.80
    local w4 = 1 / (1 - 0.10)
    local w5 = 1 / (1 - 0.40)
    local w6 = 1 / (1 - 0.70)
    local sum_w = `w1' + `w2' + `w3' + `w4' + `w5' + `w6'
    local sum_wsq = `w1'^2 + `w2'^2 + `w3'^2 + `w4'^2 + `w5'^2 + `w6'^2
    local ess_hand = (`sum_w'^2) / `sum_wsq'

    psdash weights treated ps, estimand(ate)
    assert "`r(wvar)'" == "auto-generated"
    assert abs(r(mean_wt) - (`sum_w' / 6)) < 1e-10
    assert abs(r(min_wt) - min(`w1', `w2', `w3', `w4', `w5', `w6')) < 1e-10
    assert abs(r(max_wt) - max(`w1', `w2', `w3', `w4', `w5', `w6')) < 1e-10
    assert abs(r(ess) - `ess_hand') < 1e-10
    capture confirm variable _psdash_wt
    assert _rc == 111
}
_vka_result "KA6 ATE auto-weight formulas exact" `=_rc'

* KA7: generated truncation and stabilized weights are exact row by row
capture noisily {
    _vka_exact_data

    psdash weights treated ps, wvar(wt) truncate(2) generate(wt_trunc) replace
    assert wt_trunc[1] == 1
    assert wt_trunc[2] == 1
    assert wt_trunc[3] == 2
    assert wt_trunc[4] == 1
    assert wt_trunc[5] == 1
    assert wt_trunc[6] == 1
    assert abs(r(new_max) - 2) < 1e-10
    assert abs(r(new_ess) - (49 / 9)) < 1e-10

    psdash weights treated ps, wvar(wt) stabilize generate(wt_stab) replace
    forvalues i = 1/6 {
        assert abs(wt_stab[`i'] - 0.5 * wt[`i']) < 1e-10
    }
    assert abs(r(new_ess) - (81 / 21)) < 1e-10
}
_vka_result "KA7 truncate/stabilize generated weights exact by row" `=_rc'

* KA8: auto-generated estimand weights are exact row by row when materialized
capture noisily {
    _vka_exact_data

    psdash weights treated ps, estimand(ate) truncate(100) generate(w_ate) replace
    assert abs(w_ate[1] - (1 / 0.25)) < 1e-10
    assert abs(w_ate[2] - (1 / 0.50)) < 1e-10
    assert abs(w_ate[3] - (1 / 0.80)) < 1e-10
    assert abs(w_ate[4] - (1 / (1 - 0.10))) < 1e-10
    assert abs(w_ate[5] - (1 / (1 - 0.40))) < 1e-10
    assert abs(w_ate[6] - (1 / (1 - 0.70))) < 1e-10
    assert abs(r(new_ess) - r(ess)) < 1e-10
    assert "`r(wvar)'" == "auto-generated"

    psdash weights treated ps, estimand(att) truncate(100) generate(w_att) replace
    assert abs(w_att[1] - 1) < 1e-10
    assert abs(w_att[2] - 1) < 1e-10
    assert abs(w_att[3] - 1) < 1e-10
    assert abs(w_att[4] - (0.10 / (1 - 0.10))) < 1e-10
    assert abs(w_att[5] - (0.40 / (1 - 0.40))) < 1e-10
    assert abs(w_att[6] - (0.70 / (1 - 0.70))) < 1e-10
    assert abs(r(new_ess) - r(ess)) < 1e-10
    assert "`r(wvar)'" == "auto-generated"

    psdash weights treated ps, estimand(atc) truncate(100) generate(w_atc) replace
    assert abs(w_atc[1] - ((1 - 0.25) / 0.25)) < 1e-10
    assert abs(w_atc[2] - ((1 - 0.50) / 0.50)) < 1e-10
    assert abs(w_atc[3] - ((1 - 0.80) / 0.80)) < 1e-10
    assert abs(w_atc[4] - 1) < 1e-10
    assert abs(w_atc[5] - 1) < 1e-10
    assert abs(w_atc[6] - 1) < 1e-10
    assert abs(r(new_ess) - r(ess)) < 1e-10
    assert "`r(wvar)'" == "auto-generated"
}
_vka_result "KA8 auto-generated estimand weights exact by row" `=_rc'

* KA9: support generation respects if-sample rows exactly
capture noisily {
    _vka_exact_data
    psdash support treated ps if x1 <= 4, generate(in_if) replace nograph

    assert r(N) == 4
    assert abs(r(lower_bound) - 0.25) < 1e-10
    assert abs(r(upper_bound) - 0.40) < 1e-10
    assert r(n_outside) == 2
    assert r(n_outside_treated) == 1
    assert r(n_outside_control) == 1
    assert abs(r(pct_outside) - 50) < 1e-10
    assert in_if[1] == 1
    assert in_if[2] == 0
    assert missing(in_if[3])
    assert in_if[4] == 0
    assert in_if[5] == 1
    assert missing(in_if[6])
}
_vka_result "KA9 support if-sample indicator exact by row" `=_rc'

* KA10: Crump (2009) optimal alpha is the fixed-point minimizer and the
* trim bounds/count it implies are exact. Designed data: a symmetric bulk in
* [0.15,0.85] plus 5 low (0.02) and 5 high (0.97) tails that must be trimmed.
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen double ps = runiform(0.15, 0.85)
    replace ps = 0.02 in 1/5
    replace ps = 0.97 in 6/10
    gen byte treated = rbinomial(1, ps)

    psdash support treated ps, crump nograph
    * snapshot returns before any r-class command (count) clobbers r()
    local a = r(crump_alpha)
    local tl = r(trim_lower)
    local tu = r(trim_upper)
    local nt = r(n_trimmed)
    * alpha is a genuine trimming threshold inside the admissible grid
    assert `a' >= 0.01 & `a' <= 0.49
    * trim window is symmetric about 0.5 by construction
    assert abs(`tl' - `a') < 1e-12
    assert abs(`tu' - (1 - `a')) < 1e-12
    * n_trimmed matches an independent recount (the 10 injected tails)
    count if (ps < `a' | ps > 1 - `a')
    assert `nt' == r(N)
    assert `nt' == 10
    * defining property: alpha minimises |1/(a(1-a)) - 2*E[1/(e(1-e))|a<=e<=1-a]|
    * on the 0.001 refinement grid, so residual(a) <= residual(a +/- 0.001)
    gen double _ivp = 1 / (ps * (1 - ps))
    local lhs_a = 1 / (`a' * (1 - `a'))
    quietly summarize _ivp if ps >= `a' & ps <= 1 - `a'
    local res_a = abs(`lhs_a' - 2 * r(mean))
    foreach d in -0.001 0.001 {
        local al = `a' + (`d')
        local lhs = 1 / (`al' * (1 - `al'))
        quietly summarize _ivp if ps >= `al' & ps <= 1 - `al'
        assert `res_a' <= abs(`lhs' - 2 * r(mean)) + 1e-9
    }
    drop _ivp
}
_vka_result "KA10 Crump optimal alpha fixed-point minimizer + exact trim" `=_rc'

* KA11: dispersion summaries are exact. wt={1,1,4,1,1,1}: mean=1.5,
* sample SD=sqrt(1.5), so CV=sqrt(1.5)/1.5 and max_ratio=max/mean=4/1.5.
capture noisily {
    _vka_exact_data
    psdash weights treated ps, wvar(wt)
    assert abs(r(cv) - (sqrt(1.5) / 1.5)) < 1e-10
    assert abs(r(max_ratio) - (4 / 1.5)) < 1e-10
}
_vka_result "KA11 weight CV and max_ratio exact" `=_rc'

* KA12: weighted Kolmogorov-Smirnov (balance col 10) is exact. Weighted ECDFs
* of x1 by group (weights wt) diverge to 2/3 at x1=5; x2 ECDFs coincide (0).
capture noisily {
    _vka_exact_data
    psdash balance treated ps, covariates(x1 x2) wvar(wt)
    matrix B = r(balance)
    assert abs(B[1,10] - (2 / 3)) < 1e-10
    assert abs(B[2,10]) < 1e-10
}
_vka_result "KA12 weighted KS statistic exact" `=_rc'

* KA13: in the combined dashboard, overlap and support share
* _psdash_support_stats with identical (untrimmed) arguments, so their
* colliding r(pct_outside)/r(n_outside) hold the SAME value. return add is
* therefore benign: whichever panel writes last, combined reports that value.
capture noisily {
    _vka_exact_data
    psdash overlap treated ps, nograph
    local ov_pct = r(pct_outside)
    local ov_no = r(n_outside)
    psdash support treated ps, nograph
    assert abs(r(pct_outside) - `ov_pct') < 1e-10
    assert r(n_outside) == `ov_no'
    _vka_exact_data
    psdash combined treated ps, covariates(x1 x2)
    assert abs(r(pct_outside) - `ov_pct') < 1e-10
    assert r(n_outside) == `ov_no'
}
_vka_result "KA13 combined pct_outside/n_outside collision is value-identical" `=_rc'

* KA14: known-truth balance recovery. Data are generated from a logit PS in
* two confounders; the raw SMD is large, and IPTW (ATE) weights from the
* correctly specified model drive the adjusted SMD to ~0. This is the core
* diagnostic contract: correct weights => recovered balance.
capture noisily {
    clear
    set seed 20260706
    set obs 8000
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double etrue = invlogit(0.9 * x1 - 0.6 * x2)
    gen byte treat = rbinomial(1, etrue)
    logit treat x1 x2
    predict double pshat, pr
    gen double wate = cond(treat == 1, 1 / pshat, 1 / (1 - pshat))

    psdash balance treat pshat, covariates(x1 x2) wvar(wate)
    * confounding is real: at least one raw SMD is substantial
    assert r(max_smd_raw) > 0.3
    * correct IPTW recovers balance: adjusted SMDs collapse toward zero
    assert r(max_smd_adj) < 0.1
    assert r(n_imbalanced) == 0
}
_vka_result "KA14 known-truth IPTW balance recovery (correct model)" `=_rc'

capture drop _psdash_ps _psdash_wt
graph close _all

display ""
display "KNOWN-ANSWER VALIDATION SUMMARY"
display "Tests run:    " $vka_n
display "Passed:       " $vka_pass
display "Failed:       " $vka_fail

if $vka_fail > 0 {
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
