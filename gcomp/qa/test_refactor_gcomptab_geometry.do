* test_refactor_gcomptab_geometry.do - S5 gcomptab workbook geometry guard
* Coverage: workbook creation, sheet replacement, row/column geometry, key
*           labels, numeric cells, footnote presence, and sibling sheet retention.

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local testdir "`c(tmpdir)'"

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`testdir'/gcomp_s5_plus_`install_tag'"
local personal_dir "`testdir'/gcomp_s5_personal_`install_tag'"
local xlsx "`testdir'/_gcomp_s5_geometry_`install_tag'.xlsx"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

capture program drop _s5_mock_gcomp
program define _s5_mock_gcomp, eclass
    version 16.0

    capture matrix drop s5_b s5_V s5_se s5_ci s5_ci_p s5_ci_bc s5_ci_bca
    matrix s5_b = (0.21, 0.14, 0.07, 0.333, 0.09)
    matrix colnames s5_b = tce nde nie pm cde
    matrix s5_V = I(5) * 0.0004
    matrix colnames s5_V = tce nde nie pm cde
    matrix rownames s5_V = tce nde nie pm cde
    ereturn post s5_b s5_V
    ereturn local cmd "gcomp"
    ereturn local analysis_type "mediation"
    ereturn local mediation_type "obe"

    matrix s5_se = (0.02, 0.02, 0.02, 0.04, 0.02)
    matrix colnames s5_se = tce nde nie pm cde
    ereturn matrix se = s5_se

    matrix s5_ci = J(2, 5, .)
    matrix s5_ci[1,1] = 0.1708
    matrix s5_ci[1,2] = 0.1008
    matrix s5_ci[1,3] = 0.0308
    matrix s5_ci[1,4] = 0.2546
    matrix s5_ci[1,5] = 0.0508
    matrix s5_ci[2,1] = 0.2492
    matrix s5_ci[2,2] = 0.1792
    matrix s5_ci[2,3] = 0.1092
    matrix s5_ci[2,4] = 0.4114
    matrix s5_ci[2,5] = 0.1292
    matrix colnames s5_ci = tce nde nie pm cde
    matrix s5_ci_p = s5_ci
    matrix s5_ci_bc = s5_ci
    matrix s5_ci_bca = s5_ci
    matrix colnames s5_ci_p = tce nde nie pm cde
    matrix colnames s5_ci_bc = tce nde nie pm cde
    matrix colnames s5_ci_bca = tce nde nie pm cde
    ereturn matrix ci_normal = s5_ci
    ereturn matrix ci_percentile = s5_ci_p
    ereturn matrix ci_bc = s5_ci_bc
    ereturn matrix ci_bca = s5_ci_bca
end

**# S5: workbook content and geometry remain stable
local ++test_count
capture erase "`xlsx'"
capture noisily {
    clear
    set obs 1
    gen str5 marker = "keep"
    export excel using "`xlsx'", sheet("Other") firstrow(variables) replace

    _s5_mock_gcomp
    gcomptab, xlsx("`xlsx'") sheet("Table") ///
        title("First Title") footnote("First footnote") ///
        decimal(2) zebra borderstyle(thin)

    _s5_mock_gcomp
    gcomptab, xlsx("`xlsx'") sheet("Table") ///
        title("Replacement Title") footnote("Geometry footnote") ///
        decimal(2) zebra borderstyle(thin)

    confirm file "`xlsx'"
    assert r(N_effects) == 5
    assert `"`r(xlsx)'"' == "`xlsx'"
    assert `"`r(sheet)'"' == "Table"

    import excel using "`xlsx'", sheet("Table") cellrange(A1:E8) allstring clear
    assert _N == 8
    assert c(k) == 5
    ds
    assert "`r(varlist)'" == "A B C D E"

    assert A[1] == "Replacement Title"
    assert A[1] != "First Title"
    assert B[2] == "Effect"
    assert C[2] == "Estimate"
    assert D[2] == "95% CI"
    assert E[2] == "SE"
    assert B[3] == "Total Causal Effect (TCE)"
    assert B[4] == "Natural Direct Effect (NDE)"
    assert B[5] == "Natural Indirect Effect (NIE)"
    assert B[6] == "Proportion Mediated (PM)"
    assert B[7] == "Controlled Direct Effect (CDE)"
    assert B[8] == "Geometry footnote"

    assert real(C[3]) == 0.21
    assert real(C[4]) == 0.14
    assert real(C[5]) == 0.07
    assert real(C[6]) == 0.33
    assert real(C[7]) == 0.09
    assert real(E[3]) == 0.02
    assert strpos(D[3], "(") == 1
    assert strpos(D[3], ",") > 0
    assert strpos(D[3], ")") > 0

    import excel using "`xlsx'", sheet("Other") firstrow clear
    assert _N == 1
    assert marker[1] == "keep"
}
if _rc == 0 {
    display as result "  PASS: S5 gcomptab workbook geometry/content contract is stable"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 gcomptab workbook geometry/content contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S5"
}

capture erase "`xlsx'"

display ""
display as result "test_refactor_gcomptab_geometry Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_refactor_gcomptab_geometry tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
}
else {
    display as result "PASS"
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
capture ado uninstall gcomp
foreach _sub in "_" "g" {
    local _subfiles : dir "`plus_dir'/`_sub'" files "*"
    foreach _file of local _subfiles {
        capture erase "`plus_dir'/`_sub'/`_file'"
    }
    capture rmdir "`plus_dir'/`_sub'"
}
foreach _dir in "`plus_dir'" "`personal_dir'" {
    local _files : dir "`_dir'" files "*"
    foreach _file of local _files {
        capture erase "`_dir'/`_file'"
    }
    capture rmdir "`_dir'"
}

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
