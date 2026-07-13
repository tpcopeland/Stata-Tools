* test_gcomptab_doseresponse.do - Time-varying dose-response mode for gcomptab (v1.2.0)
* Covers: per-strategy table from PO# columns, strategylabels/expyears/reference,
*         RD-vs-reference (reference row = 0), nord suppression, auto-detection,
*         default PO# labels, and clean errors for non-dose-response e() results.

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_qa_bootstrap.do"

capture which gcomptab
assert _rc == 0

local testdir "`c(tmpdir)'"

* ============================================================
* Real time-varying gcomp fit (reused by the integration tests)
* Data generator mirrors crossval_timevarying.do
* ============================================================

capture program drop _g_tv_build
program define _g_tv_build
    version 16.0
    syntax, Subjects(integer)
    clear
    set seed 20260529
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

capture program drop _g_tv_fit
program define _g_tv_fit, eclass
    version 16.0
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(200) samples(5) seed(20260529)
end

_g_tv_build, subjects(300)
_g_tv_fit

* Confirm the fixture is a 3-PO time-varying result (2 interventions + observed regime)
tempname eb0
matrix `eb0' = e(b)
assert colnumb(`eb0', "PO1") != .
assert colnumb(`eb0', "PO3") != .
assert "`e(analysis_type)'" == "time_varying"

* ============================================================
* DR1: explicit doseresponse with labels, expyears, reference, RD
* ============================================================

local ++test_count
local f1 "`testdir'/dr_t1.xlsx"
capture confirm file "`f1'"
if !_rc erase "`f1'"
capture noisily {
    _g_tv_fit
    gcomptab, doseresponse strategylabels("Always HE\Never HE\Observed regime") ///
        expyears(5 0 2) reference(1) effect("Risk") ///
        xlsx("`f1'") sheet("Table 5 DR")

    assert r(k) == 3
    assert r(reference) == 1
    assert "`r(ci)'" == "normal"
    assert "`r(xlsx)'" == "`f1'"

    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 3
    assert colsof(`T') == 5
    * finite risks and CI bounds
    forvalues i = 1/3 {
        assert `T'[`i', 1] < . & `T'[`i', 1] > 0
        assert `T'[`i', 2] < . & `T'[`i', 3] < .
    }
    * exposure-years populated in order
    assert `T'[1, 4] == 5
    assert `T'[2, 4] == 0
    assert `T'[3, 4] == 2
    * RD reference row == 0; other rows nonzero
    assert `T'[1, 5] == 0
    assert `T'[2, 5] != 0 & `T'[2, 5] < .
    * file written
    capture confirm file "`f1'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: DR1 dose-response table with labels/expyears/RD"
    local ++pass_count
}
else {
    display as error "  FAIL: DR1 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR2: auto-detection (no doseresponse) on a time-varying result
* ============================================================

local ++test_count
local f2 "`testdir'/dr_t2.xlsx"
capture confirm file "`f2'"
if !_rc erase "`f2'"
capture noisily {
    _g_tv_fit
    gcomptab, xlsx("`f2'") sheet("DR auto")
    assert r(k) == 3
    tempname T2
    matrix `T2' = r(table)
    assert rowsof(`T2') == 3
    capture confirm file "`f2'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: DR2 auto-detects dose-response output"
    local ++pass_count
}
else {
    display as error "  FAIL: DR2 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR3: default PO# labels when strategylabels omitted
* ============================================================

local ++test_count
local f3 "`testdir'/dr_t3.xlsx"
capture confirm file "`f3'"
if !_rc erase "`f3'"
capture noisily {
    _g_tv_fit
    gcomptab, doseresponse xlsx("`f3'") sheet("defaults")
    assert r(k) == 3
    preserve
    import excel using "`f3'", clear sheet("defaults") cellrange(A3) allstring
    * column B (var B) holds the strategy labels; first three rows = PO1..PO3
    assert B[1] == "PO1"
    assert B[2] == "PO2"
    assert B[3] == "PO3"
    restore
}
if _rc == 0 {
    display as result "  PASS: DR3 default PO# strategy labels"
    local ++pass_count
}
else {
    display as error "  FAIL: DR3 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR4: nord suppresses the RD column in the workbook
* ============================================================

local ++test_count
local f4 "`testdir'/dr_t4.xlsx"
capture confirm file "`f4'"
if !_rc erase "`f4'"
capture noisily {
    _g_tv_fit
    gcomptab, doseresponse nord expyears(5 0 2) xlsx("`f4'") sheet("noRD")
    assert r(k) == 3
    preserve
    import excel using "`f4'", clear sheet("noRD") allstring
    * No cell anywhere should contain the RD header
    local _found_rd = 0
    foreach v of varlist _all {
        capture assert `v' != "RD vs ref"
        if _rc local _found_rd = 1
    }
    assert `_found_rd' == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: DR4 nord suppresses RD column"
    local ++pass_count
}
else {
    display as error "  FAIL: DR4 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR5: reference out of range -> clean error (rc 198)
* ============================================================

local ++test_count
capture noisily {
    _g_tv_fit
    capture gcomptab, doseresponse reference(9) xlsx("`testdir'/dr_t5.xlsx") sheet("bad")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: DR5 out-of-range reference() errors cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: DR5 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR6: expyears count exceeding k -> clean error (rc 198)
* ============================================================

local ++test_count
capture noisily {
    _g_tv_fit
    capture gcomptab, doseresponse expyears(1 2 3 4 5) xlsx("`testdir'/dr_t6.xlsx") sheet("bad")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: DR6 over-long expyears() errors cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: DR6 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR7: forcing doseresponse on a mediation result -> clean error
* (mediation e() has tce columns, no PO# columns)
* ============================================================

capture program drop _mock_med
program define _mock_med, eclass
    version 16.0
    tempname b V se cin
    matrix `b' = (0.20, 0.12, 0.08, 0.40)
    matrix colnames `b' = tce nde nie pm
    matrix `V' = J(4, 4, 0)
    forvalues j = 1/4 {
        matrix `V'[`j', `j'] = 0.01
    }
    matrix colnames `V' = tce nde nie pm
    matrix rownames `V' = tce nde nie pm
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix `se' = (0.1, 0.1, 0.1, 0.1)
    matrix colnames `se' = tce nde nie pm
    ereturn matrix se = `se'
    matrix `cin' = (0.0, 0.0, 0.0, 0.2 \ 0.4, 0.3, 0.2, 0.6)
    matrix colnames `cin' = tce nde nie pm
    ereturn matrix ci_normal = `cin'
end

local ++test_count
capture noisily {
    _mock_med
    capture gcomptab, doseresponse xlsx("`testdir'/dr_t7.xlsx") sheet("bad")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: DR7 doseresponse on mediation e() errors cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: DR7 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* DR8: mediation mode unchanged when doseresponse not requested
* (regression guard: a mediation e() still routes to the mediation branch)
* ============================================================

local ++test_count
local f8 "`testdir'/dr_t8.xlsx"
capture confirm file "`f8'"
if !_rc erase "`f8'"
capture noisily {
    _mock_med
    gcomptab, xlsx("`f8'") sheet("Mediation") title("Mediation check")
    assert r(N_effects) == 4
    assert abs(r(tce) - 0.20) < 1e-8
    capture confirm file "`f8'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: DR8 mediation mode unaffected by new branch"
    local ++pass_count
}
else {
    display as error "  FAIL: DR8 (error `=_rc')"
    local ++fail_count
}

display ""
display as text "Dose-response test summary: `pass_count' passed, `fail_count' failed (of `test_count')"
if `fail_count' > 0 {
    display "RESULT: test_gcomptab_doseresponse tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 9
}
display "RESULT: test_gcomptab_doseresponse tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
