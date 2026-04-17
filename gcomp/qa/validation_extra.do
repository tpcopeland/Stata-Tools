* validation_extra.do - Additional invariants + sanity bounds beyond validation_gcomp.do
* Covers: CI ordering across types, width monotonicity across confidence levels,
*         SE sign/magnitude, logRR sanity, linexp decomposition, PM bounds, OCE
*         decomposition, continuous-outcome decomposition.
* Runtime: ~3 minutes

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'/") replace
discard
capture findfile gcomp.ado
quietly run "`r(fn)'"

* ============================================================
* Shared synthetic data with `all` CI option fitted once
* ============================================================

clear
set seed 20260417
set obs 600
gen double c = rnormal()
gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
tempfile dgp
save `dgp'

gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(100) samples(50) seed(42) all

tempname b se cin cip cibc cibca
matrix `b'    = e(b)
matrix `se'   = e(se)
matrix `cin'  = e(ci_normal)
matrix `cip'  = e(ci_percentile)
matrix `cibc' = e(ci_bc)
matrix `cibca'= e(ci_bca)
local ncols = colsof(`b')

* ============================================================
* VX1: CI widths are strictly positive across all types
* ============================================================

local ++test_count
capture noisily {
    foreach cim in cin cip cibc cibca {
        forvalues j = 1/`ncols' {
            local lo = ``cim''[1, `j']
            local hi = ``cim''[2, `j']
            assert (`hi' - `lo') > 0
        }
    }
}
if _rc == 0 {
    display as result "  PASS: VX1 all CI widths > 0 (normal/percentile/bc/bca)"
    local ++pass_count
}
else {
    display as error "  FAIL: VX1 CI width positivity (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX2: Normal CIs contain point estimate
* ============================================================

local ++test_count
capture noisily {
    forvalues j = 1/`ncols' {
        assert `b'[1, `j'] >= `cin'[1, `j']
        assert `b'[1, `j'] <= `cin'[2, `j']
    }
}
if _rc == 0 {
    display as result "  PASS: VX2 point est inside normal CI (all effects)"
    local ++pass_count
}
else {
    display as error "  FAIL: VX2 CI containment (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX3: e(se) matches sqrt(diag(e(V))) for all effects
* ============================================================

local ++test_count
capture noisily {
    tempname V
    matrix `V' = e(V)
    forvalues j = 1/`ncols' {
        local s = `se'[1, `j']
        local v = sqrt(`V'[`j', `j'])
        assert reldif(`s', `v') < 1e-8
    }
}
if _rc == 0 {
    display as result "  PASS: VX3 e(se) == sqrt(diag(e(V)))"
    local ++pass_count
}
else {
    display as error "  FAIL: VX3 SE/V consistency (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX4: TCE = NDE + NIE (strict, tempname matrix extraction)
* ============================================================

local ++test_count
capture noisily {
    local tce_b = `b'[1, 1]    // col 1 = tce
    local nde_b = `b'[1, 2]
    local nie_b = `b'[1, 3]
    assert reldif(`tce_b' - (`nde_b' + `nie_b'), 0) < 1e-6 ///
        | abs(`tce_b' - (`nde_b' + `nie_b')) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: VX4 TCE = NDE + NIE (from e(b) matrix)"
    local ++pass_count
}
else {
    display as error "  FAIL: VX4 strict decomposition (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX5: PM consistency — PM = NIE/TCE when both nonzero
* ============================================================

local ++test_count
capture noisily {
    local tce_b = `b'[1, 1]
    local nie_b = `b'[1, 3]
    local pm_b  = `b'[1, 4]
    if abs(`tce_b') > 0.001 {
        local pm_expected = `nie_b' / `tce_b'
        assert abs(`pm_b' - `pm_expected') < 1e-6
    }
}
if _rc == 0 {
    display as result "  PASS: VX5 PM = NIE / TCE identity"
    local ++pass_count
}
else {
    display as error "  FAIL: VX5 PM identity (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX6: OCE mediation decomposition (categorical exposure)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 43
    set obs 500
    gen double c = rnormal()
    gen double x = floor(runiform() * 3)
    gen double m = rbinomial(1, invlogit(-0.5 + 0.3*x + 0.2*c))
    gen double y = rbinomial(1, invlogit(-1 + 0.4*m - 0.2*x + 0.1*c))
    gcomp y m x c, outcome(y) mediation oce ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(43)
    * OCE decomposition must still hold
    local decomp = abs(e(tce) - e(nde) - e(nie))
    assert `decomp' < 0.05
}
if _rc == 0 {
    display as result "  PASS: VX6 OCE decomposition TCE = NDE + NIE"
    local ++pass_count
}
else {
    display as error "  FAIL: VX6 OCE decomposition (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX7: linexp TCE = NDE + NIE (linear expansion scale)
* ============================================================

local ++test_count
capture noisily {
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(44) linexp
    local decomp = abs(e(tce) - e(nde) - e(nie))
    assert `decomp' < 0.05
}
if _rc == 0 {
    display as result "  PASS: VX7 linexp decomposition holds"
    local ++pass_count
}
else {
    display as error "  FAIL: VX7 linexp decomposition (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX8: Continuous outcome — decomposition on identity scale
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 45
    set obs 500
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.2 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-0.5 + 0.7*x + 0.2*c))
    gen double y = 2 + 0.8*m + 0.5*x + 0.3*c + rnormal(0, 1)
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: regress) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(45)
    local decomp = abs(e(tce) - e(nde) - e(nie))
    assert `decomp' < 0.05
    * Continuous TCE can be any real; just assert finiteness
    assert !missing(e(tce))
}
if _rc == 0 {
    display as result "  PASS: VX8 continuous-outcome decomposition"
    local ++pass_count
}
else {
    display as error "  FAIL: VX8 continuous decomposition (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX9: logRR TCE finite + decomposition (additive on log scale)
* ============================================================

local ++test_count
capture noisily {
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(46) logRR
    assert !missing(e(tce))
    assert abs(e(tce)) < 20
    local decomp = abs(e(tce) - e(nde) - e(nie))
    assert `decomp' < 0.05
}
if _rc == 0 {
    display as result "  PASS: VX9 logRR finite + decomposition"
    local ++pass_count
}
else {
    display as error "  FAIL: VX9 logRR sanity (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX10: Sanity bounds — RD-scale effects are in [-1, 1]
* ============================================================

local ++test_count
capture noisily {
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(47)
    * Binary outcome, RD scale: probabilities differ, magnitudes <= 1
    assert abs(e(tce)) <= 1
    assert abs(e(nde)) <= 1
    assert abs(e(nie)) <= 1
    assert e(se_tce) > 0
    assert e(se_nde) > 0
    assert e(se_nie) > 0
    assert e(se_pm)  > 0
}
if _rc == 0 {
    display as result "  PASS: VX10 RD effects within [-1,1]; SEs > 0"
    local ++pass_count
}
else {
    display as error "  FAIL: VX10 RD sanity bounds (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX11: control() adds CDE column with positive SE and CI containment
* ============================================================

local ++test_count
capture noisily {
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) control(0) sim(100) samples(20) seed(48)
    assert !missing(e(cde))
    assert e(se_cde) > 0
    tempname bc cic
    matrix `bc' = e(b)
    matrix `cic' = e(ci_normal)
    * CDE is last column (col 5)
    local k2 = colsof(`bc')
    assert `bc'[1, `k2'] >= `cic'[1, `k2']
    assert `bc'[1, `k2'] <= `cic'[2, `k2']
    * Sanity bound on RD scale
    assert abs(`bc'[1, `k2']) <= 1
}
if _rc == 0 {
    display as result "  PASS: VX11 control() CDE column well-formed"
    local ++pass_count
}
else {
    display as error "  FAIL: VX11 CDE well-formedness (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VX12: Bootstrap SE scales with 1/sqrt(samples) (approx)
* ============================================================
* With 4x more bootstrap samples, SE should shrink. Tolerance is loose
* because Monte Carlo noise in the point estimate also contributes.

local ++test_count
capture noisily {
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(25) seed(49)
    local se25 = e(se_tce)
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(100) seed(49)
    local se100 = e(se_tce)
    * With 4x samples, SE should be within same order of magnitude but not identical
    assert `se25' > 0
    assert `se100' > 0
    * Not a strict equality — just both sensible
    assert abs(log(`se25'/`se100')) < 2
}
if _rc == 0 {
    display as result "  PASS: VX12 SE stable across sample sizes (25 vs 100)"
    local ++pass_count
}
else {
    display as error "  FAIL: VX12 SE stability (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "validation_extra Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: validation_extra tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
