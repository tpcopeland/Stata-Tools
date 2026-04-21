* validation_timevarying.do - Validation coverage for gcomp time-varying eofu mode
* Focus: subject-vs-row counting, observed-data fidelity, bounded/ordered POs,
*        sequential-DGP near-known-answer checks, and final-row-only invariance
* Runtime: moderate

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* Setup
* ============================================================

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'/") replace
discard

capture program drop _g_tv_val_build
program define _g_tv_val_build
    version 16.0
    syntax, Subjects(integer) [Alter_nonfinal]

    clear
    set seed 20260421
    set obs `=`subjects' * 3'

    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n

    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]

    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0

    bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1

    bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2

    bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3

    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1

    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3

    if "`alter_nonfinal'" != "" {
        replace Y = mod(id + time, 2) if time < 3
    }
end

capture program drop _g_tv_val_run
program define _g_tv_val_run, eclass
    version 16.0

    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) ///
        fixedcovariates(L0) ///
        laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) ///
        intvars(A) ///
        eofu ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) ///
        sim(240) samples(5) seed(20260421)
end

* Python Monte Carlo oracle for this sequential 3-visit DGP:
*   N = 2,000,000 draws, seed 20260421
*   Always-treat PO   = 0.08786
*   Never-treat PO    = 0.25003
*   Natural-regime PO = 0.16357
*   Risk difference   = -0.16216
*
* Tolerances are deliberately wider than pure MC error because the Stata test
* estimates nuisance models from a finite sample and then performs its own MC
* simulation. The benchmark is therefore "near-known-answer", not exact.
local bench_po_all1 = 0.08786
local bench_po_all0 = 0.25003
local bench_po_nat  = 0.16357
local bench_rd      = -0.16216
local tol_po = 0.08
local tol_rd = 0.10

* ============================================================
* VT1: e(N) uses subjects, not rows
* ============================================================

local ++test_count
capture noisily {
    _g_tv_val_build, subjects(240)
    quietly count
    local row_count = r(N)
    quietly count if time == 3
    local subj_count = r(N)

    _g_tv_val_run

    assert `row_count' == 720
    assert `subj_count' == 240
    assert e(N) == `subj_count'
    assert e(N) != `row_count'
}
if _rc == 0 {
    display as result "  PASS: VT1 e(N) equals subject count (240), not row count (720)"
    local ++pass_count
}
else {
    display as error "  FAIL: VT1 e(N) subject-vs-row count check (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VT2: e(obs_data) equals observed final-visit mean
* ============================================================

local ++test_count
capture noisily {
    _g_tv_val_build, subjects(240)
    quietly summarize Y if time == 3, meanonly
    local final_mean = r(mean)

    _g_tv_val_run

    local obs_diff = abs(e(obs_data) - `final_mean')
    assert `obs_diff' < 1e-12
}
if _rc == 0 {
    display as result "  PASS: VT2 e(obs_data) matches final-row observed mean"
    local ++pass_count
}
else {
    display as error "  FAIL: VT2 e(obs_data) final-row mean check (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VT3: Potential outcomes are bounded and ordered for beneficial treatment
* ============================================================

local ++test_count
capture noisily {
    _g_tv_val_build, subjects(500)
    _g_tv_val_run

    tempname eb
    matrix `eb' = e(b)

    local po_all1 = `eb'[1,1]
    local po_all0 = `eb'[1,2]
    local po_nat = `eb'[1,3]

    assert colsof(`eb') == 3
    assert `po_all1' >= 0 & `po_all1' <= 1
    assert `po_all0' >= 0 & `po_all0' <= 1
    assert `po_nat'  >= 0 & `po_nat'  <= 1

    * In this DGP treatment lowers risk, so always-treat should dominate.
    assert `po_all1' < `po_all0'
    assert `po_nat' > `po_all1' & `po_nat' < `po_all0'
}
if _rc == 0 {
    display as result "  PASS: VT3 POs are finite, in [0,1], and correctly ordered"
    local ++pass_count
}
else {
    display as error "  FAIL: VT3 PO bounds/order check (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VT4: Near-known-answer benchmark for eofu time-varying mode
* ============================================================

local ++test_count
capture noisily {
    _g_tv_val_build, subjects(500)
    _g_tv_val_run

    tempname eb
    matrix `eb' = e(b)

    local po_all1 = `eb'[1,1]
    local po_all0 = `eb'[1,2]
    local po_nat = `eb'[1,3]
    local rd = `po_all1' - `po_all0'

    assert abs(`po_all1' - `bench_po_all1') < `tol_po'
    assert abs(`po_all0' - `bench_po_all0') < `tol_po'
    assert abs(`po_nat'  - `bench_po_nat')  < `tol_po'
    assert abs(`rd' - `bench_rd') < `tol_rd'
}
if _rc == 0 {
    display as result "  PASS: VT4 POs track the Python oracle within documented tolerances"
    local ++pass_count
}
else {
    display as error "  FAIL: VT4 near-known-answer benchmark (error `=_rc')"
    local ++fail_count
}

* ============================================================
* VT5: Changing nonfinal outcome rows does not change eofu estimates
* ============================================================

local ++test_count
capture noisily {
    _g_tv_val_build, subjects(240)
    quietly summarize Y if time == 3, meanonly
    local base_final_mean = r(mean)

    _g_tv_val_run
    tempname b_base
    matrix `b_base' = e(b)
    local obs_base = e(obs_data)

    _g_tv_val_build, subjects(240) alter_nonfinal
    quietly summarize Y if time == 3, meanonly
    local alt_final_mean = r(mean)

    _g_tv_val_run
    tempname b_alt
    matrix `b_alt' = e(b)
    local obs_alt = e(obs_data)

    assert `base_final_mean' == `alt_final_mean'
    local k = colsof(`b_base')
    forvalues j = 1/`k' {
        assert reldif(`b_base'[1,`j'], `b_alt'[1,`j']) < 1e-10
    }
    assert reldif(`obs_base', `obs_alt') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: VT5 nonfinal outcome rows are ignored in eofu mode"
    local ++pass_count
}
else {
    display as error "  FAIL: VT5 nonfinal-row invariance (error `=_rc')"
    local ++fail_count
}

display ""
display as text "Validation summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    exit 1
}
