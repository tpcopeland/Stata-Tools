* crossval_timevarying.do - External cross-validation for gcomp time-varying eofu mode
* Benchmark source: sequential 3-visit Python Monte Carlo oracle in qa/data/timevarying_python_benchmark.csv
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

capture program drop _g_tv_cv_build
program define _g_tv_cv_build
    version 16.0
    syntax, Subjects(integer)

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
end

capture program drop _g_tv_cv_run
program define _g_tv_cv_run, eclass
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
        sim(500) samples(5) seed(20260421)
end

preserve
import delimited using "`qa_dir'/data/timevarying_python_benchmark.csv", clear varnames(1) stringcols(1 3 4)
quietly levelsof metric, local(metrics)
foreach metric of local metrics {
    quietly summarize value if metric == "`metric'", meanonly
    local bench_`metric' = r(mean)
}
restore

* These tolerances are wider than the oracle's own MC error because Stata is
* fitting nuisance models on a finite dataset and then re-simulating under the
* interventions. The cross-validation target is agreement in level and direction,
* not bitwise equality.
local tol_po = 0.08
local tol_rd = 0.10

* ============================================================
* CVT1: Stata POs agree with the external benchmark
* ============================================================

local ++test_count
capture noisily {
    _g_tv_cv_build, subjects(500)
    _g_tv_cv_run

    tempname eb
    matrix `eb' = e(b)

    local po_all1 = `eb'[1,1]
    local po_all0 = `eb'[1,2]
    local po_nat = `eb'[1,3]

    assert abs(`po_all1' - `bench_po_all1') < `tol_po'
    assert abs(`po_all0' - `bench_po_all0') < `tol_po'
    assert abs(`po_nat'  - `bench_po_natural') < `tol_po'
}
if _rc == 0 {
    display as result "  PASS: CVT1 Stata PO levels agree with the Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: CVT1 PO level cross-validation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* CVT2: Risk difference agrees with the external benchmark
* ============================================================

local ++test_count
capture noisily {
    _g_tv_cv_build, subjects(500)
    _g_tv_cv_run

    tempname eb
    matrix `eb' = e(b)

    local po_all1 = `eb'[1,1]
    local po_all0 = `eb'[1,2]
    local rd = `po_all1' - `po_all0'

    assert abs(`rd' - `bench_risk_difference') < `tol_rd'
}
if _rc == 0 {
    display as result "  PASS: CVT2 risk difference agrees with the Python oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: CVT2 risk-difference cross-validation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* CVT3: Directional agreement with the external benchmark
* ============================================================

local ++test_count
capture noisily {
    _g_tv_cv_build, subjects(500)
    _g_tv_cv_run

    tempname eb
    matrix `eb' = e(b)

    local po_all1 = `eb'[1,1]
    local po_all0 = `eb'[1,2]
    local po_nat = `eb'[1,3]

    assert sign(`po_all1' - `po_all0') == sign(`bench_po_all1' - `bench_po_all0')
    assert sign(`po_nat' - `po_all0') == sign(`bench_po_natural' - `bench_po_all0')
    assert sign(`po_nat' - `po_all1') == sign(`bench_po_natural' - `bench_po_all1')
}
if _rc == 0 {
    display as result "  PASS: CVT3 Stata matches benchmark direction and ordering"
    local ++pass_count
}
else {
    display as error "  FAIL: CVT3 directional cross-validation (error `=_rc')"
    local ++fail_count
}

display ""
display as text "Cross-validation summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    exit 1
}
