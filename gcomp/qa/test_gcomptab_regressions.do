* test_gcomptab_regressions.do - Targeted regressions for gcomptab/helper path
* Covers: no-CDE contract, apostrophe-safe paths, invalid sheet rejection,
*         stale r() clearing on export failure, helper autoload failure safety.

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

capture which gcomptab
assert _rc == 0

local testdir "`c(tmpdir)'"

* ============================================================
* Helpers: mock mediation results with and without CDE
* ============================================================

capture program drop mock_gcomp
program define mock_gcomp, eclass
    version 16.0
    syntax, tce(real) nde(real) nie(real) pm(real) cde(real) ///
        [se_tce(real 0.05) se_nde(real 0.04) se_nie(real 0.03) ///
         se_pm(real 0.02) se_cde(real 0.04)]

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

capture program drop mock_gcomp_nocde
program define mock_gcomp_nocde, eclass
    version 16.0
    tempname b V se_mat cin cip cibc cibca
    matrix `b' = (0.15, 0.10, 0.05, 0.33)
    matrix colnames `b' = tce nde nie pm
    matrix `V' = J(4, 4, 0)
    matrix `V'[1,1] = 0.03^2
    matrix `V'[2,2] = 0.025^2
    matrix `V'[3,3] = 0.015^2
    matrix `V'[4,4] = 0.08^2
    matrix colnames `V' = tce nde nie pm
    matrix rownames `V' = tce nde nie pm
    ereturn post `b' `V'
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"
    matrix `se_mat' = (0.03, 0.025, 0.015, 0.08)
    matrix colnames `se_mat' = tce nde nie pm
    ereturn matrix se = `se_mat'

    foreach ci in cin cip cibc cibca {
        matrix ``ci'' = J(2, 4, .)
    }
    matrix `cin'[1,1] = 0.15 - 1.96*0.03
    matrix `cin'[2,1] = 0.15 + 1.96*0.03
    matrix `cin'[1,2] = 0.10 - 1.96*0.025
    matrix `cin'[2,2] = 0.10 + 1.96*0.025
    matrix `cin'[1,3] = 0.05 - 1.96*0.015
    matrix `cin'[2,3] = 0.05 + 1.96*0.015
    matrix `cin'[1,4] = 0.33 - 1.96*0.08
    matrix `cin'[2,4] = 0.33 + 1.96*0.08
    foreach ci in cin cip cibc cibca {
        matrix ``ci'' = `cin'
        matrix colnames ``ci'' = tce nde nie pm
    }
    ereturn matrix ci_normal = `cin'
    ereturn matrix ci_percentile = `cip'
    ereturn matrix ci_bc = `cibc'
    ereturn matrix ci_bca = `cibca'
end

* ============================================================
* R1: no-CDE contract from installed-user gcomptab
* ============================================================

local ++test_count
capture erase "`testdir'/mediation_results.xlsx"
capture noisily {
    mock_gcomp_nocde
    gcomptab, xlsx("`testdir'/mediation_results.xlsx") sheet("Table 1") ///
        title("Causal Mediation Analysis")
    confirm file "`testdir'/mediation_results.xlsx"
    assert r(N_effects) == 4
    capture assert r(cde) != .
    local has_cde = (_rc == 0)
    assert `has_cde' == 0
    assert `"`r(sheet)'"' == "Table 1"
}
if _rc == 0 {
    display as result "  PASS: R1 no-CDE contract is correct"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 no-CDE contract (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/mediation_results.xlsx"

* ============================================================
* R2: apostrophes are allowed in xlsx() and sheet()
* ============================================================

local ++test_count
local apost = char(39)
local apost_xlsx "`testdir'/O`apost'Brien_results.xlsx"
local apost_sheet "O`apost'Brien"
capture erase "`apost_xlsx'"
capture noisily {
    mock_gcomp_nocde
    gcomptab, xlsx("`apost_xlsx'") sheet("`apost_sheet'")
    confirm file "`apost_xlsx'"
    assert `"`r(xlsx)'"' == "`apost_xlsx'"
    assert `"`r(sheet)'"' == "`apost_sheet'"
}
if _rc == 0 {
    display as result "  PASS: R2 apostrophes are accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 apostrophe-safe paths (error `=_rc')"
    local ++fail_count
}
capture erase "`apost_xlsx'"

* ============================================================
* R3: invalid colon in sheet() is rejected before export
* ============================================================

local ++test_count
capture erase "`testdir'/_gcomptab_colon.xlsx"
capture noisily {
    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    capture gcomptab, xlsx("`testdir'/_gcomptab_colon.xlsx") sheet("Bad:Sheet")
    assert _rc == 198
    capture confirm file "`testdir'/_gcomptab_colon.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: R3 colon is rejected early"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 invalid sheet rejection (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_gcomptab_colon.xlsx"

* ============================================================
* R4: failed export clears stale r() macros
* ============================================================

local ++test_count
capture erase "`testdir'/_gcomptab_good.xlsx"
capture noisily {
    tempfile export_blocker
    file open fh using "`export_blocker'", write text replace
    file close fh

    mock_gcomp, tce(0.15) nde(0.10) nie(0.05) pm(0.33) cde(0.08)
    gcomptab, xlsx("`testdir'/_gcomptab_good.xlsx") sheet("Good")
    assert `"`r(xlsx)'"' == "`testdir'/_gcomptab_good.xlsx"
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
    display as result "  PASS: R4 failed export clears r()"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 stale r() after failure (error `=_rc')"
    local ++fail_count
}
capture erase "`testdir'/_gcomptab_good.xlsx"

* ============================================================
* R5: helper autoload failure restores varabbrev safely
* ============================================================

local ++test_count
capture erase "`testdir'/_gcomptab_helperless.xlsx"
capture noisily {
    local helperless_dir "`testdir'/helperless_gcomptab_reg"
    capture mkdir "`helperless_dir'"
    filefilter "`pkg_dir'/gcomptab.ado" "`helperless_dir'/gcomptab.ado", ///
        from("_gcomp_xl_common.ado") to("_gcomp_xl_missing_for_test.ado") replace

    foreach p in gcomptab _gcomp_col_letter _gcomp_validate_path ///
        _gcomp_xl_footnote _gcomp_xl_open _gcomp_xl_validate_sheet {
        capture program drop `p'
    }
    quietly run "`helperless_dir'/gcomptab.ado"

    mock_gcomp_nocde
    set varabbrev on
    capture gcomptab, xlsx("`testdir'/_gcomptab_helperless.xlsx") sheet("NoHelper")
    assert _rc == 111
    assert "`c(varabbrev)'" == "on"
    capture confirm file "`testdir'/_gcomptab_helperless.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: R5 missing helper path restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 helper autoload failure path (error `=_rc')"
    local ++fail_count
}
set varabbrev off
capture erase "`testdir'/_gcomptab_helperless.xlsx"
capture erase "`testdir'/helperless_gcomptab_reg/gcomptab.ado"
capture rmdir "`testdir'/helperless_gcomptab_reg"

* ============================================================
* Cleanup
* ============================================================

capture program drop mock_gcomp
capture program drop mock_gcomp_nocde

* ============================================================
* Summary
* ============================================================

display ""
display as result "test_gcomptab_regressions Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_gcomptab_regressions tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
