* test_doc_examples.do - Run help-file + README examples verbatim
* Covers: Documentation Reality (SKILL.md category 13) — every displayed example
*         must be runnable exactly as printed. Uses small sim/samples for speed.
* Runtime: ~2 minutes

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

local testdir "`c(tmpdir)'"

* ============================================================
* D1: sthlp Example 1 — binary exposure OBE mediation
* ============================================================
* (from gcomp.sthlp §Examples: "Mediation analysis with binary exposure (OBE)")

local ++test_count
capture noisily {
    clear
    set seed 12345
    set obs 1000
    gen double c = rnormal(50, 10)
    gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
    gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(42)
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    assert !missing(e(tce))
}
if _rc == 0 {
    display as result "  PASS: D1 sthlp Example 1 (OBE binary exposure)"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 sthlp Example 1 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* D2: sthlp Example 2 — categorical exposure (OCE) mediation
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 54321
    set obs 1000
    gen double c = rnormal()
    gen double x = floor(runiform() * 3)
    gen double m = rbinomial(1, invlogit(-0.5 + 0.3 * x + 0.2 * c))
    gen double y = rbinomial(1, invlogit(-1 + 0.4 * m - 0.2 * x + 0.1 * c))
    gcomp y m x c, outcome(y) mediation oce ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(42)
    assert "`e(mediation_type)'" == "oce"
    * OCE with multi-level exposure: effects are vector-valued (TCE(1), TCE(2), ...)
    * — check e(b) instead of the scalar e(tce).
    tempname _b
    matrix `_b' = e(b)
    assert colsof(`_b') >= 4
}
if _rc == 0 {
    display as result "  PASS: D2 sthlp Example 2 (OCE categorical exposure)"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 sthlp Example 2 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* D3: sthlp Example 4 — gcomp -> gcomptab pipeline
* ============================================================

local ++test_count
local xlsx "`testdir'/_docex_med.xlsx"
capture erase "`xlsx'"
capture noisily {
    clear
    set seed 12345
    set obs 1000
    gen double c = rnormal(50, 10)
    gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
    gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(42)
    gcomptab, xlsx("`xlsx'") sheet("Table 1") ///
        title("Causal Mediation: Smoking Effect via Inflammation")
    confirm file "`xlsx'"
}
if _rc == 0 {
    display as result "  PASS: D3 sthlp Example 4 (gcomp->gcomptab)"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 sthlp Example 4 (error `=_rc')"
    local ++fail_count
}
capture erase "`xlsx'"

* ============================================================
* D4: README snippet — time-varying g-formula with intvars
* ============================================================
* Mirrors the README example as displayed: baseline covariate L0, time-varying
* confounder L, explicit lagged state, and eofu option.

local ++test_count
capture noisily {
    clear
    set seed 20260421
    set obs 360
    gen long id = ceil(_n / 3)
    bysort id: gen int time = _n
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

    gen byte outcome = 0
    bysort id (time): replace outcome = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3

    gcomp outcome L0 A L Alag Llag id time, outcome(outcome) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, outcome: logit, L: regress) ///
        equations(A: L0 L, outcome: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        sim(120) samples(5) seed(20260421) eofu
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "time_varying"
    tempname _eb
    matrix `_eb' = e(b)
    local PO1 = `_eb'[1,1]
    local PO2 = `_eb'[1,2]
    local PO3 = `_eb'[1,3]
    assert colsof(`_eb') == 3
    assert `PO1' >= 0 & `PO1' <= 1
    assert `PO2' >= 0 & `PO2' <= 1
    assert `PO3' >= 0 & `PO3' <= 1
    assert abs(`PO1' - `PO2') > 0.01
    assert `PO1' < `PO2'
    assert `PO3' > `PO1' & `PO3' < `PO2'
}
if _rc == 0 {
    display as result "  PASS: D4 README time-varying example returns ordered nondegenerate POs"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 README time-varying (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "test_doc_examples Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_doc_examples tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
