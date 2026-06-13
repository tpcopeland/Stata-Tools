* validation_survtab.do - known-answer validation for survtab
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_output_quality.do, validation_tabtools_issue_rendering.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _valsurv
log using "validation_survtab.log", replace text name(_valsurv)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
* xlsx checker: single canonical copy in Stata-Dev (no per-package duplicate)
local _statadev : env STATA_DEV_DIR
if "`_statadev'" == "" {
    local _home : env HOME
    local _statadev "`_home'/Stata-Dev"
}
local checker "`_statadev'/_devkit/stata_dev_cli/xlsx/check_xlsx.py"
local checker "`checker'"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: KM estimates and log-rank p

**# VC7: survtab — KM estimates and log-rank p
* =========================================================================

* Frame variables: c1 (labels), c2 (values/group 1), title

* --- VC7.1: median matches stci ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    quietly stci, median
    local ref_median = r(p50)

    capture frame drop _vc_surv
    survtab, times(10 20 30) median frame(_vc_surv)

    assert abs(r(median_1) - `ref_median') < 0.5
}
if _rc == 0 {
    display as result "  PASS: VC7.1 — survtab median matches stci"
    local ++pass_count
}
else {
    display as error "  FAIL: VC7.1 — survtab median accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_surv

* --- VC7.2: log-rank p-value matches sts test ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    sts test drug
    local ref_chi2 = r(chi2)
    local ref_df = r(df)
    local ref_p = chi2tail(`ref_df', `ref_chi2')

    capture frame drop _vc_surv2
    survtab, times(10 20 30) by(drug) frame(_vc_surv2)

    * survtab returns r(logrank_chi2) and r(logrank_p)
    assert abs(r(logrank_chi2) - `ref_chi2') < 0.01
    assert abs(r(logrank_p) - `ref_p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: VC7.2 — survtab log-rank p matches sts test"
    local ++pass_count
}
else {
    display as error "  FAIL: VC7.2 — survtab log-rank p accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_surv2

* --- VC7.3: survtab r(table) contains survival probabilities ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    tempvar _ref_surv
    tempname _km_ref
    qui sts generate `_ref_surv' = s
    matrix `_km_ref' = J(3, 1, .)
    local _times "10 20 30"
    forvalues _i = 1/3 {
        local _time : word `_i' of `_times'
        qui su _t if _t <= `_time' & _st & !missing(`_ref_surv'), meanonly
        if r(N) > 0 {
            local _max_t = r(max)
            qui su `_ref_surv' if _t == `_max_t' & _st, meanonly
            matrix `_km_ref'[`_i', 1] = r(min)
        }
        else {
            matrix `_km_ref'[`_i', 1] = 1
        }
    }

    capture frame drop _vc_surv3
    survtab, times(10 20 30) frame(_vc_surv3)

    assert rowsof(r(table)) == 3
    assert colsof(r(table)) == 1
    forvalues i = 1/3 {
        assert abs(r(table)[`i', 1] - `_km_ref'[`i', 1]) < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS: VC7.3 — survtab S(20) matches KM estimate"
    local ++pass_count
}
else {
    display as error "  FAIL: VC7.3 — survtab KM accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_surv3




* =========================================================================

**# Migrated: log-rank cross-check

**# VC10: survtab — log-rank p-value cross-check
* =========================================================================

* --- VC10.1: survtab log-rank p matches direct sts test ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    sts test drug
    local _ref_p = chi2tail(r(df), r(chi2))

    survtab, by(drug) times(10 20)
    assert abs(r(logrank_p) - `_ref_p') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC10.1 — survtab log-rank p matches sts test"
    local ++pass_count
}
else {
    display as error "  FAIL: VC10.1 — survtab log-rank p (rc=`=_rc')"
    local ++fail_count
    capture frame drop _vc_slogrank
}

* =========================================================================

**# Migrated: events/atrisk conservation

**# KE6: survtab — events/atrisk conservation, log-rank vs sts test
* =========================================================================

* --- KE6.1: Total events across groups equals dataset events ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    quietly count if died == 1
    local total_events = r(N)

    survtab, times(20) by(drug) events
    local sum_ev = 0
    forvalues g = 1/2 {
        local sum_ev = `sum_ev' + r(events_`g')
    }
    assert `sum_ev' == `total_events'
}
if _rc == 0 {
    display as result "  PASS: KE6.1 — survtab events sum to total died"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.1 — survtab events sum (rc=`=_rc')"
    local ++fail_count
}

* --- KE6.2: Sum of at-risk equals total observations ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    local total_n = _N

    survtab, times(20) by(drug) events
    local sum_atrisk = 0
    forvalues g = 1/2 {
        local sum_atrisk = `sum_atrisk' + r(atrisk_`g')
    }
    assert `sum_atrisk' == `total_n'
}
if _rc == 0 {
    display as result "  PASS: KE6.2 — survtab at-risk sums to total N"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.2 — survtab at-risk sum (rc=`=_rc')"
    local ++fail_count
}

* --- KE6.2b: stsplit data still report subjects/events, not episodes ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    gen long id = _n
    quietly stset studytime, failure(died) id(id)
    quietly stsplit split_t, at(10 20 30)
    assert _N > 48

    quietly levelsof drug, local(drug_levels)
    local g = 0
    foreach lev of local drug_levels {
        local ++g
        tempvar _sub_tag _evt_tag
        quietly egen byte `_sub_tag' = tag(id) if drug == `lev'
        quietly count if `_sub_tag'
        local exp_n_`g' = r(N)
        quietly egen byte `_evt_tag' = tag(id) if drug == `lev' & _d == 1
        quietly count if `_evt_tag'
        local exp_e_`g' = r(N)
    }

    survtab, times(20) by(drug) events
    foreach g of numlist 1/2 {
        assert r(atrisk_`g') == `exp_n_`g''
        assert r(events_`g') == `exp_e_`g''
    }
}
if _rc == 0 {
    display as result "  PASS: KE6.2b — survtab uses subject counts after stsplit"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.2b — survtab stsplit subject counts (rc=`=_rc')"
    local ++fail_count
}

* --- KE6.3: log-rank chi2 / p match sts test ---
local ext_n_total = `n_total'
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    quietly sts test drug
    local ref_chi2 = r(chi2)
    local ref_df   = r(df)

    survtab, times(20) by(drug)
    assert abs(r(logrank_chi2) - `ref_chi2') < 1e-3
    * p computed independently
    local ref_p = chi2tail(`ref_df', `ref_chi2')
    assert abs(r(logrank_p) - `ref_p') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: KE6.3 — survtab log-rank chi2/p match sts test"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.3 — log-rank vs sts test (rc=`=_rc')"
    local ++fail_count
}

* --- KE6.4: Median survival per group matches stci ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)

    quietly stci if drug == 0, median
    local med_ref_0 = r(p50)
    quietly stci if drug == 1, median
    local med_ref_1 = r(p50)

    survtab, times(20) by(drug) median
    * Group 1 = drug==0 (placebo), Group 2 = drug==1 (treatment)
    if r(median_1) < . {
        assert abs(r(median_1) - `med_ref_0') < 1e-3
    }
    if r(median_2) < . {
        assert abs(r(median_2) - `med_ref_1') < 1e-3
    }
}
if _rc == 0 {
    display as result "  PASS: KE6.4 — survtab medians match stci by group"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.4 — survtab median (rc=`=_rc')"
    local ++fail_count
}

* --- KE6.5: RMST(g) ≤ truncation horizon ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    survtab, times(20) by(drug) rmst(20)
    forvalues g = 1/2 {
        local _r = r(rmst_`g')
        if "`_r'" != "" & `_r' < . {
            assert `_r' >= 0
            assert `_r' <= 20 + 1e-6
        }
    }
}
if _rc == 0 {
    display as result "  PASS: KE6.5 — RMST values bounded in [0, horizon]"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.5 — RMST bounds (rc=`=_rc')"
    local ++fail_count
}

* --- KE6.6: RMST and SE match stci, rmean ---
local ++n_total
capture noisily {
    clear
    input byte(g died) double t
    0 1 5
    0 1 10
    0 0 20
    1 1 6
    1 1 12
    1 0 20
    end
    quietly stset t, failure(died)

    survtab, times(20) by(g) rmst(20)
    local got0 = r(rmst_1)
    local se0 = r(rmst_se_1)
    local got1 = r(rmst_2)
    local se1 = r(rmst_se_2)

    quietly stci if g == 0, rmean
    assert abs(`got0' - r(rmean)) < 1e-8
    assert abs(`se0' - r(se)) < 1e-8

    quietly stci if g == 1, rmean
    assert abs(`got1' - r(rmean)) < 1e-8
    assert abs(`se1' - r(se)) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: KE6.6 — survtab RMST/SE match stci, rmean"
    local ++pass_count
}
else {
    display as error "  FAIL: KE6.6 — survtab RMST vs stci (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: shared Excel-checking helpers

local checker ""
foreach _trypath in "`qa_dir'/tools" {
    capture confirm file "`checker'"
    if _rc == 0 {
        local checker "`checker'"
        continue, break
    }
}
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found — using Stata-native Excel validation"

    * Stata-native fallback: generate xlsx, verify title cells with import excel
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        capture erase "`output_dir'/_va_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_va_native_regtab.xlsx") sheet("Test") title("Regression") digits(2)
        import excel "`output_dir'/_va_native_regtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Regression"
        * Check for p-value patterns in data rows
        local _has_pval = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
            }
        }
        assert `_has_pval' == 1
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_va_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_va_native_effecttab.xlsx") sheet("ATE") ///
            title("Effects") effect("ATE") clean
        import excel "`output_dir'/_va_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Effects"
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * Cleanup
    capture erase "`output_dir'/_va_native_regtab.xlsx"
    capture erase "`output_dir'/_va_native_effecttab.xlsx"

    display _newline as result "Stata-native Excel Accuracy Validation Complete"
    display as result "  Passed: `pass_count' / `n_total'"
    if `fail_count' > 0 {
        display as error "  Failed: `fail_count' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `fail_count' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* =========================================================================

**# Migrated: survival probabilities in Excel

**# VA8: survtab — survival probabilities in Excel
* =========================================================================

* --- VA8.1: survtab median survival in Excel ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get median for drug==1 (placebo)
    quietly stci if drug == 1, median
    local med_plac = r(p50)
    local med_plac_fmt : display %9.1f `med_plac'
    local med_plac_fmt = strtrim("`med_plac_fmt'")

    capture erase "`output_dir'/_va_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("`output_dir'/_va_survtab.xlsx") ///
        sheet("Test") median

    shell python3 "`checker'" "`output_dir'/_va_survtab.xlsx" --sheet "Test" ///
        --cell-contains C3 "`med_plac_fmt'" ///
        --contains "Median" ///
        --result-file "`output_dir'/_va_sv1.txt" --quiet
    file open _fh using "`output_dir'/_va_sv1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA8.1 — survtab median survival matches stci in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA8.1 — survtab median accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_sv1.txt"

* =========================================================================

**# Migrated: survival estimate quality

**# SECTION 5: survtab — validate survival estimates
* ============================================================

* V11: survtab exact KM and log-rank values
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly sts test drug
    local chi2_ref = r(chi2)
    local p_ref = chi2tail(r(df), r(chi2))

    survtab, times(10 20 30) by(drug) ///
        xlsx("`output_dir'/_val_survtab.xlsx") sheet("surv")

    assert r(N_rows) == 9
    assert rowsof(r(table)) == 3
    assert colsof(r(table)) == 3
    assert abs(r(table)[1,1] - 0.45) < 1e-10
    assert abs(r(table)[1,2] - 0.85119048) < 1e-8
    assert abs(r(table)[1,3] - 0.85714286) < 1e-8
    assert abs(r(table)[2,1] - 0.1125) < 1e-10
    assert abs(r(table)[2,2] - 0.62065972) < 1e-8
    assert abs(r(table)[2,3] - 0.85714286) < 1e-8
    assert abs(r(table)[3,1] - 0) < 1e-10
    assert abs(r(table)[3,2] - 0.20688657) < 1e-8
    assert abs(r(table)[3,3] - 0.5877551) < 1e-7
    assert abs(r(logrank_chi2) - `chi2_ref') < 1e-10
    assert abs(r(logrank_p) - `p_ref') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: V11 survtab exact KM and log-rank values"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 survtab exact KM and log-rank values (error `=_rc')"
    local ++fail_count
}

* V12: survtab median/CI matches stci
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly stci if drug == 1
    local med_1 = r(p50)
    local med_lb_1 = r(lb)
    local med_ub_1 = r(ub)
    quietly stci if drug == 2
    local med_2 = r(p50)
    local med_lb_2 = r(lb)
    local med_ub_2 = r(ub)

    survtab, times(10 20 30) by(drug) median ///
        xlsx("`output_dir'/_val_survtab_med.xlsx") sheet("median") ///
        frame(_val_survmed)

    local ci_1 `"(`=string(`med_lb_1', "%5.1f")', `=string(`med_ub_1', "%5.1f")')"'
    local med_1_fmt : display %5.1f `med_1'
    local med_2_fmt : display %5.1f `med_2'
    local med_1_fmt = strtrim("`med_1_fmt'")
    local med_2_fmt = strtrim("`med_2_fmt'")
    frame _val_survmed {
        assert c1[3] == "Median survival, yr"
        assert c2[3] == "`med_1_fmt'"
        assert c3[3] == "`med_2_fmt'"
        assert c1[4] == "  (95% CI)"
        assert c2[4] == "`ci_1'"
        assert c3[4] == ""
    }
    assert r(median_1) == `med_1'
    assert r(median_2) == `med_2'
    frame drop _val_survmed
}
if _rc == 0 {
    display as result "  PASS: V12 survtab median/CI matches stci"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 survtab median/CI matches stci (error `=_rc')"
    local ++fail_count
}

* V13: survtab reverse is exact complement of forward KM
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(20) frame(_val_surv_fwd) ///
        xlsx("`output_dir'/_val_survtab_fwd.xlsx") sheet("fwd")
    matrix _fwd = r(table)
    * Get cumulative incidence at time 20
    survtab, times(20) reverse frame(_val_surv_rev) ///
        xlsx("`output_dir'/_val_survtab_rev.xlsx") sheet("rev")
    matrix _rev = r(table)

    assert rowsof(_fwd) == rowsof(_rev)
    assert colsof(_fwd) == colsof(_rev)
    forvalues i = 1/`=rowsof(_fwd)' {
        forvalues j = 1/`=colsof(_fwd)' {
            assert abs(_fwd[`i',`j'] + _rev[`i',`j'] - 1) < 1e-10
        }
    }
    frame drop _val_surv_fwd
    frame drop _val_surv_rev
}
if _rc == 0 {
    display as result "  PASS: V13 survtab reverse is exact complement"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 survtab reverse is exact complement (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: issue rendering checks (survtab/crosstab)

local checker "`tools_dir'/check_tabtools_render.py"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_tabtools_render.py not available"
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 local python_cmd "python3"
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "FAIL: python/openpyxl render checker runtime not available"
    exit 601
}

local skip_count = 0
local failed_tests ""

* Validation 1: crosstab boldp() keeps chi-squared and trend rows bold
local _render_status1 ""
capture noisily {
    clear
    input outcome exposure freq
    0 0 25
    1 0 5
    0 1 15
    1 1 15
    0 2 5
    1 2 25
    end
    expand freq
    capture erase "`output_dir'/crosstab_boldp.xlsx"
    capture erase "`output_dir'/crosstab_boldp.txt"
    crosstab outcome exposure, trend xlsx("`output_dir'/crosstab_boldp.xlsx") ///
        sheet("Cross") boldp(0.05)
    shell `python_cmd' "`checker'" "`output_dir'/crosstab_boldp.xlsx" --sheet Cross ///
        --row-contains-bold "Pearson's chi-squared test" ///
        --row-contains-bold "P for trend =" ///
        --result-file "`output_dir'/crosstab_boldp.txt"
    file open _fh using "`output_dir'/crosstab_boldp.txt", read text
    file read _fh _line
    file close _fh
    local _render_status1 "`_line'"
    assert "`_render_status1'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: crosstab boldp() bolds test and trend rows"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab boldp() bolds test and trend rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Validation 2: survtab boldp() and highlight() produce semantic row formatting
local _render_status2 ""
capture noisily {
    clear
    set obs 40
    gen byte group = (_n > 20)
    gen double time = cond(group == 0, 1 + mod(_n - 1, 3), 5 + mod(_n - 21, 3))
    gen byte event = (group == 0)
    stset time, failure(event)
    capture erase "`output_dir'/survtab_styles.xlsx"
    capture erase "`output_dir'/survtab_styles.txt"
    survtab, times(1 2 3) by(group) xlsx("`output_dir'/survtab_styles.xlsx") ///
        sheet("Surv") boldp(0.05) highlight(0.05)
    shell `python_cmd' "`checker'" "`output_dir'/survtab_styles.xlsx" --sheet Surv ///
        --row-contains-bold "Log-rank test:" ///
        --row-contains-fill "Log-rank test:" "255 255 204" ///
        --result-file "`output_dir'/survtab_styles.txt"
    file open _fh using "`output_dir'/survtab_styles.txt", read text
    file read _fh _line
    file close _fh
    local _render_status2 "`_line'"
    assert "`_render_status2'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: survtab boldp()/highlight() render bold and highlight"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab boldp()/highlight() render bold and highlight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

}  // close `if has_checker' block (Excel-checker VA tests)

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_survtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valsurv
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_survtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valsurv

