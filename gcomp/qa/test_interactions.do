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

do "`qa_dir'/_qa_bootstrap.do"

local testdir "`c(tmpdir)'"

* ============================================================
* Helper: run a standard mediation fit so e() is populated
* ============================================================

capture program drop _fit_mediation
program define _fit_mediation
    syntax [, ALL]
    clear
    set seed 777
    set obs 400
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
    if "`all'" != "" {
        gen double m = 0.8*x + 0.5*c + rnormal(0, 0.7)
        gen double y = rbinomial(1, invlogit(-0.5 + 0.7*m + 0.5*x + 0.2*c))
        local commands "m: regress, y: logit"
    }
    else {
        gen double m = rbinomial(1, invlogit(-0.4 + 1.2*x + 0.3*c))
        gen double y = rbinomial(1, invlogit(-0.8 + 1.0*m + 0.8*x + 0.2*c))
        local commands "m: logit, y: logit"
    }
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(`commands') ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(20) seed(1) `all'
end

capture program drop _mock_mediation_results
program define _mock_mediation_results, eclass
    version 16.0
    local tce = 0.15
    local nde = 0.10
    local nie = 0.05
    local pm  = 0.33
    local cde = 0.08
    local se_tce = 0.03
    local se_nde = 0.02
    local se_nie = 0.015
    local se_pm  = 0.08
    local se_cde = 0.04

    tempname b V se_mat cin cip cibc cibca
    matrix `b' = (`tce', `nde', `nie', `pm', `cde')
    matrix colnames `b' = tce nde nie pm cde
    matrix `V' = J(5, 5, 0)
    matrix `V'[1,1] = `se_tce'^2
    matrix `V'[2,2] = `se_nde'^2
    matrix `V'[3,3] = `se_nie'^2
    matrix `V'[4,4] = `se_pm'^2
    matrix `V'[5,5] = `se_cde'^2
    matrix colnames `V' = tce nde nie pm cde
    matrix rownames `V' = tce nde nie pm cde
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    ereturn scalar tce = `tce'
    ereturn scalar nde = `nde'
    ereturn scalar nie = `nie'
    ereturn scalar pm = `pm'
    ereturn scalar cde = `cde'

    matrix `se_mat' = (`se_tce', `se_nde', `se_nie', `se_pm', `se_cde')
    matrix colnames `se_mat' = tce nde nie pm cde
    ereturn matrix se = `se_mat'

    foreach ci in cin cip cibc cibca {
        matrix ``ci'' = J(2, 5, .)
    }
    forvalues j = 1/5 {
        local vals tce nde nie pm cde
        local se_vals se_tce se_nde se_nie se_pm se_cde
        local v : word `j' of `vals'
        local s : word `j' of `se_vals'
        matrix `cin'[1,`j'] = ``v'' - 1.96*``s''
        matrix `cin'[2,`j'] = ``v'' + 1.96*``s''
        matrix `cip'[1,`j'] = ``v'' - 2.00*``s''
        matrix `cip'[2,`j'] = ``v'' + 1.90*``s''
        matrix `cibc'[1,`j'] = ``v'' - 2.05*``s''
        matrix `cibc'[2,`j'] = ``v'' + 1.85*``s''
        matrix `cibca'[1,`j'] = ``v'' - 2.10*``s''
        matrix `cibca'[2,`j'] = ``v'' + 1.80*``s''
    }
    foreach ci in cin cip cibc cibca {
        matrix colnames ``ci'' = tce nde nie pm cde
    }
    ereturn matrix ci_normal = `cin'
    ereturn matrix ci_percentile = `cip'
    ereturn matrix ci_bc = `cibc'
    ereturn matrix ci_bca = `cibca'
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

    assert r(N_effects) == 4
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
    _fit_mediation, all
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
* I11: Apostrophes in xlsx() path and sheet() name are allowed
* ============================================================

local ++test_count
local apost = char(39)
local apost_xlsx "`testdir'/O`apost'Brien_results.xlsx"
local apost_sheet "O`apost'Brien"
capture erase "`apost_xlsx'"
capture noisily {
    _mock_mediation_results
    gcomptab, xlsx("`apost_xlsx'") sheet("`apost_sheet'")
    confirm file "`apost_xlsx'"
    assert `"`r(xlsx)'"' == "`apost_xlsx'"
    assert `"`r(sheet)'"' == "`apost_sheet'"
}
if _rc == 0 {
    display as result "  PASS: I11 apostrophes allowed in xlsx() and sheet()"
    local ++pass_count
}
else {
    display as error "  FAIL: I11 apostrophe validation (error `=_rc')"
    local ++fail_count
}
capture erase "`apost_xlsx'"

* ============================================================
* I12: Invalid colon in sheet() is rejected before export
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i12.xlsx"
capture noisily {
    _mock_mediation_results
    capture gcomptab, xlsx("`testdir'/_itest_i12.xlsx") sheet("Bad:Sheet")
    assert _rc == 198
    capture confirm file "`testdir'/_itest_i12.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: I12 sheet() rejects colon before export"
    local ++pass_count
}
else {
    display as error "  FAIL: I12 invalid sheet name (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i12.xlsx"

* ============================================================
* I13: Failed export clears r(xlsx), r(sheet), and r(ci)
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i13_ok.xlsx"
capture noisily {
    tempfile export_blocker
    file open _i13fh using "`export_blocker'", write text replace
    file close _i13fh

    _mock_mediation_results
    gcomptab, xlsx("`testdir'/_itest_i13_ok.xlsx") sheet("Good")
    assert `"`r(xlsx)'"' == "`testdir'/_itest_i13_ok.xlsx"
    assert `"`r(sheet)'"' == "Good"
    assert `"`r(ci)'"' == "normal"

    capture gcomptab, xlsx("`export_blocker'/fail.xlsx") sheet("Fail")
    assert _rc != 0
    assert `"`r(xlsx)'"' == ""
    assert `"`r(sheet)'"' == ""
    assert `"`r(ci)'"' == ""

    capture erase "`export_blocker'"
}
if _rc == 0 {
    display as result "  PASS: I13 failed export clears stale r() macros"
    local ++pass_count
}
else {
    display as error "  FAIL: I13 stale r() after export failure (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_itest_i13_ok.xlsx"

* ============================================================
* I14: Missing helper install does not leak varabbrev
* ============================================================

local ++test_count
capture erase "`testdir'/_itest_i14.xlsx"
capture noisily {
    local helperless_dir "`testdir'/helperless_gcomptab"
    capture mkdir "`helperless_dir'"
    filefilter "`pkg_dir'/gcomptab.ado" "`helperless_dir'/gcomptab.ado", ///
        from("_gcomp_xl_common.ado") to("_gcomp_xl_missing_for_test.ado") replace

    foreach p in gcomptab _gcomp_col_letter _gcomp_validate_path ///
        _gcomp_xl_footnote _gcomp_xl_open _gcomp_xl_validate_sheet {
        capture program drop `p'
    }
    quietly run "`helperless_dir'/gcomptab.ado"

    _mock_mediation_results
    set varabbrev on
    capture gcomptab, xlsx("`testdir'/_itest_i14.xlsx") sheet("NoHelper")
    assert _rc == 111
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: I14 missing helper path restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: I14 helper autoload failure path (error `=_rc')"
    local ++fail_count
}
set varabbrev off
capture erase "`testdir'/_itest_i14.xlsx"
capture erase "`testdir'/helperless_gcomptab/gcomptab.ado"
capture rmdir "`testdir'/helperless_gcomptab"

* ============================================================
* Cleanup
* ============================================================

capture program drop _fit_mediation
capture program drop _mock_mediation_results
foreach k in i1 i2 i3 i7 i8 i9 i12 i13 i14 {
    capture erase "`testdir'/_itest_`k'.xlsx"
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "test_interactions Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_interactions tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "FAIL"
    exit 1
}
else {
    display "RESULT: test_interactions tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    display as result "PASS"
}
