* test_msm_diagtab.do
* Cross-contrast weight-diagnostics accumulation (msm_diagnose, accumulate())
* and styled export (msm_diagtab).

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tools_dir "`qa_dir'/tools"

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

local work_dir "`c(tmpdir)'/msm_diagtab_qa"
capture mkdir "`work_dir'"

capture program drop _read_check_status
program define _read_check_status, rclass
    version 16.0
    args status_file
    local status "FAIL"
    capture confirm file "`status_file'"
    if _rc == 0 {
        tempname fh
        file open `fh' using "`status_file'", read text
        file read `fh' status
        file close `fh'
    }
    return local status "`status'"
end

* Build a weighted panel and accumulate one diagnostic row.
*   1 = full sample, with explicit balance covariates
*   2 = subset, balance via default covariates
*   3 = no covariates mapped -> balance columns missing
capture program drop _diag_panel
program define _diag_panel
    version 16.0
    args mode frame contrast outcome
    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    if "`mode'" == "2" keep if id <= 300

    if "`mode'" == "3" {
        msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    }
    else {
        msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity) ///
            baseline_covariates(age sex)
    }
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog

    if "`mode'" == "1" {
        msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
            accumulate(`frame') contrast(`"`contrast'"') outcome(`"`outcome'"')
    }
    else {
        msm_diagnose, accumulate(`frame') contrast(`"`contrast'"') outcome(`"`outcome'"')
    }
end

* -------------------------------------------------------------------------
* T1: accumulate two contrasts -> frame with 2 rows and the fixed schema
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop wd
    _diag_panel 1 wd "C1: class A vs platform" "death"
    _diag_panel 2 wd "C2: class B vs platform" "death"

    frame wd {
        assert _N == 2
        * schema present
        confirm str variable contrast outcome
        confirm numeric variable n_obs ess ess_pct max_weight p99_weight ///
            n_extreme n_imbalanced max_abs_smd
        * finite analytical payload in every row
        assert n_obs > 0 & !missing(n_obs)
        assert ess > 0 & !missing(ess)
        assert ess_pct > 0 & ess_pct <= 100 & !missing(ess_pct)
        assert !missing(n_imbalanced)
        assert !missing(max_abs_smd)
        * labels round-tripped
        assert contrast[1] == "C1: class A vs platform"
        assert outcome[1]  == "death"
    }
}
if _rc == 0 {
    display as result "  PASS T1: accumulate builds a 2-row schema frame"
    local ++pass_count
}
else {
    display as error "  FAIL T1: accumulate frame (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

* -------------------------------------------------------------------------
* T2: msm_diagtab exports a styled sheet (title, header, 2 data rows, footnote)
* -------------------------------------------------------------------------
local wd_xlsx "`work_dir'/wd.xlsx"
capture erase "`wd_xlsx'"
local ++test_count
capture noisily msm_diagtab, frame(wd) xlsx("`wd_xlsx'") sheet("WD") ///
    title("Per-contrast diagnostics") borderstyle(medium) zebra
if _rc == 0 capture confirm file "`wd_xlsx'"
if _rc == 0 {
    display as result "  PASS T2: msm_diagtab export runs and writes a file"
    local ++pass_count
}
else {
    display as error "  FAIL T2: msm_diagtab export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

local ++test_count
tempfile t3_status
local checker "`pkg_dir'/qa/tools/check_xlsx.py"
capture noisily shell python3 "`checker'" "`wd_xlsx'" ///
    --sheet WD ///
    --exact-rows 5 ///
    --exact-cols 10 ///
    --cell A1 "Per-contrast diagnostics" ///
    --merged-row 1 ///
    --header-row 2 Contrast Outcome "N (pp)" ESS "ESS (%)" "Max weight" "P99 weight" "N extreme" "N imbalanced" "Max |SMD|" ///
    --bold-row-all 2 ///
    --fill-color 2 "219 229 241" ///
    --cell-not-empty A3 D3 E3 J3 ///
    --cell A3 "C1: class A vs platform" ///
    --italic-row 5 ///
    --row-contains 5 "ESS%" ///
    --result-file "`t3_status'"
quietly _read_check_status "`t3_status'"
if "`r(status)'" == "PASS" {
    display as result "  PASS T3: msm_diagtab sheet structure and styling"
    local ++pass_count
}
else {
    display as error "  FAIL T3: msm_diagtab sheet structure"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

* -------------------------------------------------------------------------
* T4: balance columns are missing (shown n/a) when no covariates are assessed
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop wdn
    _diag_panel 3 wdn "C3: no covariates" ""
    frame wdn {
        assert _N == 1
        assert missing(n_imbalanced)
        assert missing(max_abs_smd)
        * non-balance payload still finite
        assert ess > 0 & !missing(ess)
    }
}
if _rc == 0 {
    display as result "  PASS T4: balance columns missing when balance not assessed"
    local ++pass_count
}
else {
    display as error "  FAIL T4: missing-balance path (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

local wdn_xlsx "`work_dir'/wdn.xlsx"
capture erase "`wdn_xlsx'"
local ++test_count
capture noisily msm_diagtab, frame(wdn) xlsx("`wdn_xlsx'")
if _rc == 0 {
    tempfile t5_status
    capture noisily shell python3 "`checker'" "`wdn_xlsx'" ///
        --sheet "Weight Diagnostics" ///
        --exact-rows 4 ///
        --cell I3 "n/a" ///
        --cell J3 "n/a" ///
        --result-file "`t5_status'"
    quietly _read_check_status "`t5_status'"
}
if "`r(status)'" == "PASS" {
    display as result "  PASS T5: n/a rendered for missing balance cells"
    local ++pass_count
}
else {
    display as error "  FAIL T5: n/a rendering"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

* -------------------------------------------------------------------------
* T6: contrast() required when accumulate() given (rc 198)
* -------------------------------------------------------------------------
local ++test_count
capture frame drop wdguard
capture noisily _diag_panel 1 wdguard "" ""
* _diag_panel passes contrast("") so msm_diagnose should reject
capture {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) ///
        truncate(1 99) nolog
    msm_diagnose, accumulate(wdguard)
}
if _rc == 198 {
    display as result "  PASS T6: contrast() required with accumulate() (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL T6: expected rc 198, got `=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

* -------------------------------------------------------------------------
* T7: empty frame -> rc 459
* -------------------------------------------------------------------------
local ++test_count
capture frame drop wdempty
frame create wdempty str80 contrast str40 outcome double(n_obs ess ess_pct ///
    max_weight p99_weight n_extreme n_imbalanced max_abs_smd)
capture noisily msm_diagtab, frame(wdempty) xlsx("`work_dir'/empty.xlsx") replace
if _rc == 459 {
    display as result "  PASS T7: empty frame errors with rc 459"
    local ++pass_count
}
else {
    display as error "  FAIL T7: expected rc 459, got `=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

* -------------------------------------------------------------------------
* T8: missing frame -> rc 111
* -------------------------------------------------------------------------
local ++test_count
capture frame drop wdmissing
capture noisily msm_diagtab, frame(wdmissing) xlsx("`work_dir'/missing.xlsx") replace
if _rc == 111 {
    display as result "  PASS T8: missing frame errors with rc 111"
    local ++pass_count
}
else {
    display as error "  FAIL T8: expected rc 111, got `=_rc'"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

* -------------------------------------------------------------------------
* T9: regression -- msm_diagnose WITHOUT accumulate is unchanged (r() + table)
* -------------------------------------------------------------------------
local reg_xlsx "`work_dir'/reg.xlsx"
capture erase "`reg_xlsx'"
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) ///
        truncate(1 99) nolog
    msm_diagnose, balance_covariates(biomarker comorbidity age sex)
    * r() payload intact
    assert !missing(r(ess))
    assert !missing(r(ess_pct))
    assert !missing(r(max_weight))
    assert !missing(r(p99_weight))
    assert !missing(r(n_extreme))
    matrix bcheck = r(balance)
    assert rowsof(bcheck) == 4
    * downstream export still works off the same diagnostics
    msm_table, xlsx("`reg_xlsx'") balance weights replace
    confirm file "`reg_xlsx'"
}
if _rc == 0 {
    display as result "  PASS T9: msm_diagnose w/o accumulate unchanged; msm_table works"
    local ++pass_count
}
else {
    display as error "  FAIL T9: regression (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

* -------------------------------------------------------------------------
* T10: msm_diagtab is nclass -- leaves no r() return surface
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    return clear
    msm_diagtab, frame(wd) xlsx("`work_dir'/nclass.xlsx") replace
    mata: st_local("r_n_scalars",  strofreal(rows(st_dir("r()", "numscalar", "*"))))
    mata: st_local("r_n_macros",   strofreal(rows(st_dir("r()", "macro", "*"))))
    mata: st_local("r_n_matrices", strofreal(rows(st_dir("r()", "matrix", "*"))))
    assert `r_n_scalars' == 0
    assert `r_n_macros' == 0
    assert `r_n_matrices' == 0
}
if _rc == 0 {
    display as result "  PASS T10: msm_diagtab leaves no r() return surface"
    local ++pass_count
}
else {
    display as error "  FAIL T10: msm_diagtab r() surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

* -------------------------------------------------------------------------
* T11: package root left clean (no stray logs / workbooks)
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    local root_logs : dir "`pkg_dir'" files "*.log"
    local root_smcl : dir "`pkg_dir'" files "*.smcl"
    local root_xlsx : dir "`pkg_dir'" files "*.xlsx"
    local n_root = wordcount(`"`root_logs' `root_smcl' `root_xlsx'"')
    assert `n_root' == 0
}
if _rc == 0 {
    display as result "  PASS T11: no stray artifacts in package root"
    local ++pass_count
}
else {
    display as error "  FAIL T11: root artifact hygiene (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

* -------------------------------------------------------------------------
* T12: formatting options (decimals, threshold, font, fontsize, footnote, open)
* -------------------------------------------------------------------------
local opt_xlsx "`work_dir'/diagtab_opts.xlsx"
capture erase "`opt_xlsx'"
local ++test_count
capture noisily msm_diagtab, frame(wd) xlsx("`opt_xlsx'") decimals(2) ///
    threshold(0.2) font("Calibri") fontsize(12) ///
    footnote("Custom diagnostic note") open
if _rc == 0 {
    tempfile t12_status
    capture noisily shell python3 "`checker'" "`opt_xlsx'" ///
        --sheet "Weight Diagnostics" ///
        --exact-rows 5 ///
        --font Calibri ///
        --number-format F3 "0.00" ///
        --row-contains 5 "Custom diagnostic note" ///
        --result-file "`t12_status'"
    quietly _read_check_status "`t12_status'"
}
if "`r(status)'" == "PASS" {
    display as result "  PASS T12: msm_diagtab formatting options applied"
    local ++pass_count
}
else {
    display as error "  FAIL T12: msm_diagtab formatting options"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

display as text ""
display as text "========================================"
display as text "MSM_DIAGTAB QA SUMMARY"
display as text "========================================"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}

capture erase "`wd_xlsx'"
capture erase "`wdn_xlsx'"
capture erase "`reg_xlsx'"
capture erase "`work_dir'/empty.xlsx"
capture erase "`work_dir'/missing.xlsx"
capture erase "`work_dir'/nclass.xlsx"
capture erase "`opt_xlsx'"

display as text "RESULT: test_msm_diagtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
