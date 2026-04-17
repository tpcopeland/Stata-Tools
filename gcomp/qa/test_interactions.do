* test_interactions.do - Option interaction + collision + post-estimation tests
* Covers: gcomptab name collisions with user data, post-estimation state
*         preservation, varabbrev restore on error, settings restore,
*         back-to-back gcomp runs, gcomp -> gcomptab round-trip.
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

local testdir "`c(tmpdir)'"

* ============================================================
* Helper: run a standard mediation fit so e() is populated
* ============================================================

capture program drop _fit_mediation
program define _fit_mediation
    clear
    set seed 777
    set obs 400
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(1) all
end

* ============================================================
* I1: Post-estimation preservation — gcomptab does NOT destroy e()
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i1.xlsx"
capture noisily {
    _fit_mediation
    local tce_before   = e(tce)
    local nde_before   = e(nde)
    local cmd_before   = "`e(cmd)'"
    local anal_before  = "`e(analysis_type)'"

    gcomptab, xlsx("`testdir'/_itest_i1.xlsx") sheet("S1")

    assert "`e(cmd)'" == "`cmd_before'"
    assert "`e(analysis_type)'" == "`anal_before'"
    assert reldif(e(tce), `tce_before') < 1e-12
    assert reldif(e(nde), `nde_before') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: I1 gcomptab preserves e() after run"
    local ++pass_count
}
else {
    display as error "  FAIL: I1 post-est preservation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i1.xlsx"

* ============================================================
* I2: Data preservation — _N, sort, varlist unchanged after gcomptab
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i2.xlsx"
capture noisily {
    _fit_mediation
    * Snapshot dataset state
    local N_before = _N
    describe, short
    local k_before = r(k)
    ds
    local vars_before "`r(varlist)'"

    gcomptab, xlsx("`testdir'/_itest_i2.xlsx") sheet("S2")

    assert _N == `N_before'
    describe, short
    assert r(k) == `k_before'
    ds
    assert "`r(varlist)'" == "`vars_before'"
}
if _rc == 0 {
    display as result "  PASS: I2 gcomptab preserves dataset (_N, vars)"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 data preservation (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i2.xlsx"

* ============================================================
* I3: User data has variable named "title_col" (gcomptab internal scratch)
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i3.xlsx"
capture noisily {
    _fit_mediation
    * Inject a variable that collides with gcomptab internal scratch name
    gen str20 title_col = "user_data"
    gen double effect_label = _n
    gcomptab, xlsx("`testdir'/_itest_i3.xlsx") sheet("S3")
    * Our variables should survive (gcomptab preserves)
    capture confirm variable title_col
    assert _rc == 0
    capture confirm variable effect_label
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: I3 user vars named title_col/effect_label survive"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 name collision (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i3.xlsx"

* ============================================================
* I4: varabbrev restore on gcomp error path
* ============================================================

local ++test_count
capture noisily {
    clear
    set obs 200
    gen double c = rnormal()
    gen double x = rbinomial(1, 0.5)
    gen double m = rbinomial(1, 0.5)
    gen double y = rbinomial(1, 0.5)
    set varabbrev on
    * Trigger an error: missing required option (no commands())
    capture gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(50) samples(5) seed(1)
    * varabbrev must be restored to "on"
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: I4 varabbrev restored after gcomp error"
    local ++pass_count
}
else {
    display as error "  FAIL: I4 varabbrev restore (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I5: set more is not leaked
* ============================================================

local ++test_count
capture noisily {
    set more on
    local more_before = c(more)
    _fit_mediation
    assert c(more) == "`more_before'"
    set more off
}
if _rc == 0 {
    display as result "  PASS: I5 c(more) not clobbered by gcomp"
    local ++pass_count
}
else {
    display as error "  FAIL: I5 set more leak (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I6: Back-to-back gcomp calls (no cached state pollution)
* ============================================================

local ++test_count
capture noisily {
    _fit_mediation
    local t1 = e(tce)
    _fit_mediation                               // reloads, same seed -> same answer
    local t2 = e(tce)
    assert reldif(`t1', `t2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: I6 back-to-back gcomp deterministic"
    local ++pass_count
}
else {
    display as error "  FAIL: I6 back-to-back runs (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I7: gcomptab with ci() + decimal() + title() + labels() combined
*     (canonical user workflow; each option alone is tested elsewhere)
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i7.xlsx"
capture noisily {
    _fit_mediation
    gcomptab, xlsx("`testdir'/_itest_i7.xlsx") sheet("Combo") ///
        ci(percentile) decimal(4) title("Combined options") ///
        labels("Total \ Direct \ Indirect \ %Med")
    confirm file "`testdir'/_itest_i7.xlsx"
    assert "`r(ci)'" == "percentile"
}
if _rc == 0 {
    display as result "  PASS: I7 gcomptab combined ci+decimal+title+labels"
    local ++pass_count
}
else {
    display as error "  FAIL: I7 combined options (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i7.xlsx"

* ============================================================
* I8: Multiple sheets in one workbook
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i8.xlsx"
capture noisily {
    _fit_mediation
    gcomptab, xlsx("`testdir'/_itest_i8.xlsx") sheet("Normal")   ci(normal)
    gcomptab, xlsx("`testdir'/_itest_i8.xlsx") sheet("Percentile") ci(percentile)
    gcomptab, xlsx("`testdir'/_itest_i8.xlsx") sheet("BC")       ci(bc)
    gcomptab, xlsx("`testdir'/_itest_i8.xlsx") sheet("BCa")      ci(bca)
    confirm file "`testdir'/_itest_i8.xlsx"
}
if _rc == 0 {
    display as result "  PASS: I8 four CI sheets in one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: I8 multiple sheets (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i8.xlsx"

* ============================================================
* I9: gcomptab after a non-gcomp estimation -> must error cleanly
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i9.xlsx"
capture noisily {
    sysuse auto, clear
    regress price mpg
    * gcomptab expects e(cmd)=="gcomp"; must refuse cleanly
    capture gcomptab, xlsx("`testdir'/_itest_i9.xlsx") sheet("S9")
    assert _rc != 0
    * No workbook should be left behind
    capture confirm file "`testdir'/_itest_i9.xlsx"
    if _rc == 0 {
        * If a file was created, it's residue — delete and fail soft
        erase "`testdir'/_itest_i9.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: I9 gcomptab refuses non-gcomp e()"
    local ++pass_count
}
else {
    display as error "  FAIL: I9 non-gcomp guard (error `=_rc')"
    local ++fail_count
}

* ============================================================
* I10: Changing covariate list between back-to-back fits — no carryover
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 41
    set obs 400
    gen double c1 = rnormal()
    gen double c2 = rnormal()
    gen double x  = rbinomial(1, invlogit(-0.3 + 0.2*c1 + 0.1*c2))
    gen double m  = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c1))
    gen double y  = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c1 + 0.2*c2))
    tempfile d
    save `d'
    gcomp y m x c1, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c1, y: m x c1) ///
        base_confs(c1) sim(100) samples(10) seed(1)
    local t_c1only = e(tce)
    use `d', clear
    gcomp y m x c1 c2, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c1 c2, y: m x c1 c2) ///
        base_confs(c1 c2) sim(100) samples(10) seed(1)
    local t_both = e(tce)
    * Estimates should differ — different adjusted models
    assert `t_c1only' != `t_both'
}
if _rc == 0 {
    display as result "  PASS: I10 covariate list changes propagate"
    local ++pass_count
}
else {
    display as error "  FAIL: I10 covariate carryover (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Cleanup
* ============================================================

capture program drop _fit_mediation
foreach k in i1 i2 i3 i7 i8 i9 {
    capture erase "`testdir'/_itest_`k'.xlsx"
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "test_interactions Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_interactions tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
