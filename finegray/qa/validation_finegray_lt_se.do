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

**# ---------------------------------------------------------------
**# 4-5. Published same-group stratified ZZF path: score identity and jackknife
**# ---------------------------------------------------------------
* The original checks above have one weight stratum, so they cannot distinguish
* the historical symmetric stabilizer from Zhang-Zhang-Fine equation (7).  Use
* x2 for both censoring and entry grouping to exercise the paper's published
* same-group construction directly.
quietly use `base', clear
quietly stset t, failure(d) enter(t0v) id(id)
quietly finegray x1 x2, compete(status) cause(1) ///
    strata(x2) truncstrata(x2) nolog
matrix Vrs = e(V)
scalar se1s = sqrt(Vrs[1,1])
scalar se2s = sqrt(Vrs[2,2])
quietly finegray_cif, at(x1=0.5 x2=1) attime(1) ci
matrix CAs = r(table)
scalar cifses = CAs[1,3]

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
        bg = st_data(., "x2")
        tg = st_data(., "x2")
        G = _finegray_km_censor(t, dd, 0, et, bg, t0)
        b = st_matrix("e(b)")'
        sc = _finegray_score_residuals(t, dd, 1, 0, et, Z, b, G,
                                       bg, t0, tg)
        st_numscalar("css_max", max(abs(colsum(sc))))
    }
    restore
    assert scalar(css_max) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: stratified ZZF score-residual sum identity (max=" scalar(css_max) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: stratified ZZF score-residual identity (rc=`=_rc')"
    local ++fail_count
}

scalar ss1 = 0
scalar qs1 = 0
scalar ss2 = 0
scalar qs2 = 0
scalar ssc1 = 0
scalar qsc1 = 0
scalar njks = 0
foreach i of local ids {
    quietly {
        use `base', clear
        drop if id == `i'
        stset t, failure(d) enter(t0v) id(id)
        capture finegray x1 x2, compete(status) cause(1) ///
            strata(x2) truncstrata(x2) nolog
        if _rc == 0 {
            scalar njks = njks + 1
            scalar ss1 = ss1 + _b[x1]
            scalar qs1 = qs1 + _b[x1]^2
            scalar ss2 = ss2 + _b[x2]
            scalar qs2 = qs2 + _b[x2]^2
            finegray_cif, at(x1=0.5 x2=1) attime(1)
            matrix JS = r(table)
            scalar ssc1 = ssc1 + JS[1,2]
            scalar qsc1 = qsc1 + JS[1,2]^2
        }
    }
}
scalar jse1s = sqrt((njks-1)/njks * (qs1 - ss1^2/njks))
scalar jse2s = sqrt((njks-1)/njks * (qs2 - ss2^2/njks))
scalar jcses = sqrt((njks-1)/njks * (qsc1 - ssc1^2/njks))

local ++test_count
capture noisily {
    assert njks == 150
    display as text "  strat x1: robust=" %9.6f se1s " jackknife=" %9.6f jse1s " ratio=" %6.4f se1s/jse1s
    display as text "  strat x2: robust=" %9.6f se2s " jackknife=" %9.6f jse2s " ratio=" %6.4f se2s/jse2s
    display as text "  strat CIF: analytic=" %9.6f cifses " jackknife=" %9.6f jcses " ratio=" %6.4f cifses/jcses
    assert se1s/jse1s > `lo' & se1s/jse1s < `hi'
    assert se2s/jse2s > `lo' & se2s/jse2s < `hi'
    assert cifses/jcses > `lo' & cifses/jcses < `hi'
}
if _rc == 0 {
    display as result "  PASS: stratified ZZF coefficient and CIF SEs match jackknife"
    local ++pass_count
}
else {
    display as error "  FAIL: stratified ZZF SEs match jackknife (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 6. Factorized cross-classification: score-residual sum identity
**# ---------------------------------------------------------------
* Zhang et al.'s published construction uses the same grouping for both
* product-limit factors.  The package additionally permits distinct censoring
* and entry groupings, so its robust-score factorization needs an explicit
* cross-classified check rather than borrowing the same-group result.
quietly use `base', clear
quietly gen byte cg = (x1 > 0)
quietly stset t, failure(d) enter(t0v) id(id)
quietly finegray x1 x2, compete(status) cause(1) ///
    strata(cg) truncstrata(x2) nolog

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
        bg = st_data(., "cg")
        tg = st_data(., "x2")
        G = _finegray_km_censor(t, dd, 0, et, bg, t0)
        b = st_matrix("e(b)")'
        sc = _finegray_score_residuals(t, dd, 1, 0, et, Z, b, G,
                                       bg, t0, tg)
        st_numscalar("csx_max", max(abs(colsum(sc))))
    }
    restore
    assert scalar(csx_max) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: cross-classified score-residual sum identity (max=" scalar(csx_max) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: cross-classified score-residual identity (rc=`=_rc')"
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
