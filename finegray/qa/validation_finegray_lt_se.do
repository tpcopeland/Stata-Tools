* validation_finegray_lt_se.do
* Oracles for robust/influence-function SEs under LEFT TRUNCATION (delayed
* entry), the case fixed in v1.1.1: the per-subject score residuals must
* restrict each subject's at-risk contribution to its own risk window
* [t0_i, T_i].
*
* Oracle 1 (exact identity): the score-residual decomposition must reproduce
* the total score, which is ~0 at the converged betahat. Before the fix the
* column sums on delayed-entry data were O(10); after it they are O(1e-13).
*
* Oracle 2 (independent mechanism): delete-one jackknife of the coefficients
* on a seeded delayed-entry DGP. The influence-function (robust) SE is
* consistent for the same asymptotic variance but computed by entirely
* different code; it sits slightly below the jackknife because the censoring
* weights G(t) are treated as known (same behaviour validated for t0=0 in
* validation_finegray_cif_se.do).
*
* Oracle 3 (independent mechanism): delete-one jackknife of the CIF point
* estimate at a fixed horizon/profile on the same delayed-entry fit,
* validating the influence-function CIF SE (finegray_cif) under left
* truncation.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_lt_se.log", replace name(_lts)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Acceptable analytic/jackknife SE ratio (see validation_finegray_cif_se.do)
local lo = 0.85
local hi = 1.10

**# ---------------------------------------------------------------
**# Seeded delayed-entry competing-risks DGP (single fit, reused)
**# ---------------------------------------------------------------
clear
set seed 20260701
set obs 150
gen long id = _n
gen double x1 = rnormal()
gen double x2 = rbinomial(1, .4)
gen double u = runiform()
gen double te = -ln(u)/exp(.5*x1 - .3*x2)
gen double tc = 0.3 + runiform()*3
gen double t = min(te, tc)
gen byte d = te <= tc
gen byte status = 0
replace status = 1 if d & runiform() > .4
replace status = 2 if d & status == 0
gen double t0v = runiform()*0.4*t
stset t, failure(d) enter(t0v) id(id)
quietly finegray x1 x2, compete(status) cause(1) nolog
matrix Vr = e(V)
scalar se1 = sqrt(Vr[1,1])
scalar se2 = sqrt(Vr[2,2])
quietly finegray_cif, at(x1=0.5 x2=1) attime(1) ci
matrix CA = r(table)
scalar cifse = CA[1,3]

**# ---------------------------------------------------------------
**# 1. Score-residual sum identity under delayed entry
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    preserve
    quietly keep if e(sample)
    sort _t
    mata {
        Z = st_data(., ("x1", "x2"))
        t = st_data(., "_t")
        dd = st_data(., "_d")
        et = st_data(., "status")
        t0 = st_data(., "_t0")
        G = _finegray_km_censor(t, dd, 0, et, J(rows(t), 1, 1), t0)
        b = st_matrix("e(b)")'
        /* 11 args, not 10: the ZZF work added the truncation-stratum column
           (tg_id) and this call was never updated, so it had been dying with
           r(3001) -- a red suite nobody was tracking.  The fit above has no
           truncstrata(), so every subject is in one truncation stratum. */
        sc = _finegray_score_residuals(t, dd, 1, 0, et, Z, b, G,
                                       J(rows(t), 1, 1), t0,
                                       J(rows(t), 1, 1))
        st_numscalar("cs_max", max(abs(colsum(sc))))
    }
    restore
    assert scalar(cs_max) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: score-residual sum identity under delayed entry (max=" scalar(cs_max) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: score-residual sum identity under delayed entry (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# Delete-one jackknife (shared loop): coefficients and CIF(1 | x1=.5, x2=1)
**# ---------------------------------------------------------------
preserve
quietly keep if e(sample)
quietly levelsof id, local(ids)
tempfile base
quietly save `base'

scalar s1 = 0
scalar q1 = 0
scalar s2 = 0
scalar q2 = 0
scalar sc1 = 0
scalar qc1 = 0
scalar njk = 0
foreach i of local ids {
    quietly {
        use `base', clear
        drop if id == `i'
        stset t, failure(d) enter(t0v) id(id)
        capture finegray x1 x2, compete(status) cause(1) nolog
        if _rc == 0 {
            scalar njk = njk + 1
            scalar s1 = s1 + _b[x1]
            scalar q1 = q1 + _b[x1]^2
            scalar s2 = s2 + _b[x2]
            scalar q2 = q2 + _b[x2]^2
            finegray_cif, at(x1=0.5 x2=1) attime(1)
            matrix J = r(table)
            scalar sc1 = sc1 + J[1,2]
            scalar qc1 = qc1 + J[1,2]^2
        }
    }
}
restore

scalar jse1 = sqrt((njk-1)/njk * (q1 - s1^2/njk))
scalar jse2 = sqrt((njk-1)/njk * (q2 - s2^2/njk))
scalar jcse = sqrt((njk-1)/njk * (qc1 - sc1^2/njk))

**# ---------------------------------------------------------------
**# 2. Robust coefficient SEs vs jackknife under delayed entry
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    assert njk == 150
    display as text "  x1: robust=" %9.6f se1 " jackknife=" %9.6f jse1 " ratio=" %6.4f se1/jse1
    display as text "  x2: robust=" %9.6f se2 " jackknife=" %9.6f jse2 " ratio=" %6.4f se2/jse2
    assert se1/jse1 > `lo' & se1/jse1 < `hi'
    assert se2/jse2 > `lo' & se2/jse2 < `hi'
}
if _rc == 0 {
    display as result "  PASS: LT robust coefficient SEs match jackknife"
    local ++pass_count
}
else {
    display as error "  FAIL: LT robust coefficient SEs match jackknife (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 3. Influence-function CIF SE vs jackknife under delayed entry
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    display as text "  CIF(1): analytic=" %9.6f cifse " jackknife=" %9.6f jcse " ratio=" %6.4f cifse/jcse
    assert cifse/jcse > `lo' & cifse/jcse < `hi'
}
if _rc == 0 {
    display as result "  PASS: LT influence-function CIF SE matches jackknife"
    local ++pass_count
}
else {
    display as error "  FAIL: LT influence-function CIF SE matches jackknife (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline "RESULT: validation_finegray_lt_se tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _lts
    exit 1
}
display as result "ALL TESTS PASSED"
log close _lts
