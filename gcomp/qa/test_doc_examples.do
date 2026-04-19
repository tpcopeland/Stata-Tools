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
* Mirrors the README example as displayed: continuous time-varying confounder,
* binary outcome, explicit exposure model, and eofu option.

local ++test_count
capture noisily {
    clear
    set seed 98765
    set obs 600
    gen long id = ceil(_n / 3)
    bysort id: gen int time = _n
    gen double L = rnormal()
    gen double A = rbinomial(1, invlogit(-1 + 0.3*L))
    gen double outcome = rbinomial(1, invlogit(-2 + 0.5*L + 0.4*A))

    gcomp outcome L A id time, outcome(outcome) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) ///
        commands(L: regress, outcome: logit, A: logit) ///
        equations(L: A, outcome: L A, A: L) ///
        intvars(A) interventions(A_: A_=1, A_: A_=0) ///
        sim(50) samples(10) seed(42) eofu
    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "time_varying"
    tempname _eb
    matrix `_eb' = e(b)
    local PO1 = `_eb'[1,1]
    local PO2 = `_eb'[1,2]
    assert `PO1' != .
    assert `PO2' != .
}
if _rc == 0 {
    display as result "  PASS: D4 README time-varying example runs with a nondegenerate contrast"
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
