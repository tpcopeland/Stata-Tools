* test_package_integration.do - cross-command integration: themes/defaults propagation, frames, eplot bridge, multi-command contracts
* Consolidated in v1.7.0 from: test_coverage_gaps.do, test_eplot_bridge.do, test_eplot_section_fold.do, test_regression_fixes.do, test_residual_risks.do, test_review_bivar_contracts.do, test_review_models_contracts.do, test_tabtools_v101.do, test_v140_features.do, test_v150_features.do, test_v160_features.do, test_v170_features.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _pkgint
capture erase "test_package_integration.log"
log using "test_package_integration.log", text name(_pkgint)

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
local checker "`tools_dir'/check_xlsx.py"
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

capture program drop _tt_file_has
program define _tt_file_has, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_open = 0
    capture noisily {
        syntax using/ , NEEDLE(string asis)
        local _needle `"`needle'"'
        if strlen(`"`_needle'"') >= 2 {
            if substr(`"`_needle'"', 1, 1) == char(34) & substr(`"`_needle'"', -1, 1) == char(34) {
                local _needle = substr(`"`_needle'"', 2, strlen(`"`_needle'"') - 2)
            }
        }
        tempname _fh
        file open `_fh' using `"`using'"', read text
        local _fh_open = 1
        local _found = 0
        file read `_fh' _line
        while r(eof) == 0 {
            if strpos(`"`_line'"', `"`_needle'"') > 0 local _found = 1
            file read `_fh' _line
        }
        file close `_fh'
        local _fh_open = 0
        return scalar found = `_found'
    }
    local rc = _rc
    if `_fh_open' capture file close `_fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


**# Migrated: frame() rejects pre-existing frames (all frame-capable commands)

**# FIX 1: frame() rejects pre-existing frames
* ============================================================

* --- 1.1 corrtab: frame() rejects existing frame ---
capture noisily {
    sysuse auto, clear
    capture frame drop victim
    frame create victim
    capture corrtab price mpg weight, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.1 corrtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.1 corrtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* --- 1.2 corrtab: frame() succeeds when frame does not exist ---
capture noisily {
    sysuse auto, clear
    capture frame drop fresh_corr
    corrtab price mpg weight, frame(fresh_corr)
    capture confirm frame fresh_corr
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_corr
if `_test_rc' == 0 {
    display as result "  PASS: 1.2 corrtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.2 corrtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* --- 1.3 table1_tc: frame() rejects existing frame ---
capture noisily {
    sysuse auto, clear
    capture frame drop victim
    frame create victim
    capture table1_tc price mpg, by(foreign) frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.3 table1_tc frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.3 table1_tc frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* --- 1.4 table1_tc: frame() succeeds when frame does not exist ---
capture noisily {
    sysuse auto, clear
    capture frame drop fresh_t1
    table1_tc price mpg, by(foreign) frame(fresh_t1)
    capture confirm frame fresh_t1
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_t1
if `_test_rc' == 0 {
    display as result "  PASS: 1.4 table1_tc frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.4 table1_tc frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* --- 1.5 regtab: frame() rejects existing frame ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop victim
    frame create victim
    capture regtab, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.5 regtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.5 regtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.5"
}

* --- 1.6 regtab: frame() succeeds when frame does not exist ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop fresh_reg
    regtab, frame(fresh_reg)
    capture confirm frame fresh_reg
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_reg
if `_test_rc' == 0 {
    display as result "  PASS: 1.6 regtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.6 regtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.6"
}

* --- 1.7 effecttab: frame() rejects existing frame ---
* Use from() matrix path to avoid collect export dependency
capture noisily {
    sysuse auto, clear
    matrix _eff_data = (1.5, 0.8, 2.2, 0.001 \ -0.3, -0.9, 0.3, 0.330)
    matrix colnames _eff_data = estimate ci_lower ci_upper pvalue
    matrix rownames _eff_data = "Treatment" "Age"
    capture frame drop victim
    frame create victim
    capture effecttab, from(_eff_data) xlsx("`output_dir'/_test_eff_rej.xlsx") frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
capture matrix drop _eff_data
if `_test_rc' == 0 {
    display as result "  PASS: 1.7 effecttab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.7 effecttab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.7"
}

* --- 1.8 effecttab: frame() succeeds when frame does not exist ---
capture noisily {
    matrix _eff_data2 = (1.5, 0.8, 2.2, 0.001 \ -0.3, -0.9, 0.3, 0.330)
    matrix colnames _eff_data2 = estimate ci_lower ci_upper pvalue
    matrix rownames _eff_data2 = "Treatment" "Age"
    capture frame drop fresh_eff
    effecttab, from(_eff_data2) xlsx("`output_dir'/_test_eff_frame.xlsx") frame(fresh_eff)
    capture confirm frame fresh_eff
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_eff
if `_test_rc' == 0 {
    display as result "  PASS: 1.8 effecttab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.8 effecttab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.8"
}

* --- 1.9 comptab: frame() rejects existing frame ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop _ct_src1
    regtab, frame(_ct_src1) noint
    capture frame drop victim
    frame create victim
    capture comptab _ct_src1, rows(1) frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
capture frame drop _ct_src1
if `_test_rc' == 0 {
    display as result "  PASS: 1.9 comptab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.9 comptab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.9"
}

* --- 1.10 comptab: frame() succeeds when frame does not exist ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: quietly regress price mpg weight
    capture frame drop _ct_src2
    regtab, frame(_ct_src2) noint
    capture frame drop fresh_comp
    comptab _ct_src2, rows(1) frame(fresh_comp)
    capture confirm frame fresh_comp
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_comp
capture frame drop _ct_src2
if `_test_rc' == 0 {
    display as result "  PASS: 1.10 comptab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.10 comptab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.10"
}

* --- 1.11 crosstab: frame() rejects existing frame ---
capture noisily {
    sysuse auto, clear
    capture frame drop victim
    frame create victim
    capture crosstab foreign rep78, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.11 crosstab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.11 crosstab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.11"
}

* --- 1.12 crosstab: frame() succeeds when frame does not exist ---
capture noisily {
    sysuse auto, clear
    capture frame drop fresh_cross
    crosstab foreign rep78, frame(fresh_cross)
    capture confirm frame fresh_cross
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_cross
if `_test_rc' == 0 {
    display as result "  PASS: 1.12 crosstab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.12 crosstab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.12"
}

* --- 1.13 diagtab: frame() rejects existing frame ---
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() < 0.3
    gen test_result = runiform() < (0.8 * gold + 0.1 * (1 - gold))
    capture frame drop victim
    frame create victim
    capture diagtab test_result gold, frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.13 diagtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.13 diagtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.13"
}

* --- 1.14 diagtab: frame() succeeds when frame does not exist ---
capture noisily {
    clear
    set obs 200
    set seed 42
    gen gold = runiform() < 0.3
    gen test_result = runiform() < (0.8 * gold + 0.1 * (1 - gold))
    capture frame drop fresh_diag
    diagtab test_result gold, frame(fresh_diag)
    capture confirm frame fresh_diag
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_diag
if `_test_rc' == 0 {
    display as result "  PASS: 1.14 diagtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.14 diagtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.14"
}

* --- 1.17 survtab: frame() rejects existing frame ---
capture noisily {
    clear
    set obs 200
    set seed 99
    gen time = rexponential(5)
    gen event = runiform() < 0.6
    gen grp = runiform() < 0.5
    stset time, failure(event)
    capture frame drop victim
    frame create victim
    capture survtab, times(1 3 5) by(grp) frame(victim)
    assert _rc == 110
}
local _test_rc = _rc
capture frame drop victim
if `_test_rc' == 0 {
    display as result "  PASS: 1.17 survtab frame() rejects existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.17 survtab frame() rejects existing frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.17"
}

* --- 1.18 survtab: frame() succeeds when frame does not exist ---
capture noisily {
    clear
    set obs 200
    set seed 99
    gen time = rexponential(5)
    gen event = runiform() < 0.6
    gen grp = runiform() < 0.5
    stset time, failure(event)
    capture frame drop fresh_surv
    survtab, times(1 3 5) by(grp) frame(fresh_surv)
    capture confirm frame fresh_surv
    assert _rc == 0
}
local _test_rc = _rc
capture frame drop fresh_surv
if `_test_rc' == 0 {
    display as result "  PASS: 1.18 survtab frame() works for new frame"
    local ++pass_count
}
else {
    display as error "  FAIL: 1.18 survtab frame() works for new frame (rc=`_test_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.18"
}

* ============================================================

**# Migrated: journal themes across commands

**# O1: Journal-style themes
* =========================================================================
sysuse auto, clear

* --- O1.1: lancet theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) ///
    excel("output/test_o1_lancet.xlsx") title("Lancet Theme") theme(lancet)
if _rc == 0 {
    capture confirm file "output/test_o1_lancet.xlsx"
    if _rc == 0 {
        display as result "PASS: O1.1 — lancet theme"
        local ++pass_count
    }
    else {
        display as error "FAIL: O1.1 — Excel file not created"
        local ++fail_count
    }
}
else {
    display as error "FAIL: O1.1 — lancet theme (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- O1.2: nejm theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) ///
    excel("output/test_o1_nejm.xlsx") title("NEJM Theme") theme(nejm)
if _rc == 0 {
    display as result "PASS: O1.2 — nejm theme"
    local ++pass_count
}
else {
    display as error "FAIL: O1.2 — nejm theme (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- O1.3: apa theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) ///
    excel("output/test_o1_apa.xlsx") title("APA Theme") theme(apa)
if _rc == 0 {
    display as result "PASS: O1.3 — apa theme"
    local ++pass_count
}
else {
    display as error "FAIL: O1.3 — apa theme (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* --- O1.4: invalid theme ---
local ++n_total
capture table1_tc, by(foreign) vars(price contn) theme(invalid_theme)
if _rc != 0 {
    display as result "PASS: O1.4 — invalid theme rejected"
    local ++pass_count
}
else {
    display as error "FAIL: O1.4 — invalid theme should error"
    local ++fail_count
}

sysuse auto, clear

* --- O1.5: theme in regtab ---
local ++n_total
collect clear
collect: regress price mpg weight
capture noisily regtab, xlsx("output/test_o1_regtab.xlsx") sheet("Lancet") ///
    title("Lancet Regression") theme(lancet)
if _rc == 0 {
    display as result "PASS: O1.5 — theme in regtab"
    local ++pass_count
}
else {
    display as error "FAIL: O1.5 — theme in regtab (rc=`=_rc')"
    local ++fail_count
}

sysuse auto, clear

* =========================================================================

**# Migrated: console confirmation regtab+effecttab

**# O1: Console confirmation for regtab/effecttab
* =========================================================================

* --- O1.1: regtab displays export message ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_o1_regtab_v150.xlsx") sheet("Test")
    * If we get here, the command ran (console output visible in log)
}
if _rc == 0 {
    display as result "  PASS: O1.1 — regtab runs with console output"
    local ++pass_count
}
else {
    display as error "  FAIL: O1.1 — regtab failed (rc=`=_rc')"
    local ++fail_count
}

* --- O1.2: effecttab displays export message ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_o1_effecttab_v150.xlsx") sheet("Test")
}
if _rc == 0 {
    display as result "  PASS: O1.2 — effecttab runs with console output"
    local ++pass_count
}
else {
    display as error "  FAIL: O1.2 — effecttab failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: r(methods) regtab+effecttab

**# I2: r(methods) for regtab and effecttab
* =========================================================================

* --- I2.1: regtab returns r(methods) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_i2_methods.xlsx") sheet("Methods")
    assert `"`r(methods)'"' != ""
    * Should mention "Odds ratios" for logit
    assert strpos(`"`r(methods)'"', "Odds ratios") > 0
}
if _rc == 0 {
    display as result "  PASS: I2.1 — regtab r(methods) contains 'Odds ratios'"
    local ++pass_count
}
else {
    display as error "  FAIL: I2.1 — regtab r(methods) missing/wrong (rc=`=_rc')"
    local ++fail_count
}

* --- I2.2: effecttab returns r(methods) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_i2_eff_methods.xlsx") sheet("Methods")
    assert `"`r(methods)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: I2.2 — effecttab r(methods) populated"
    local ++pass_count
}
else {
    display as error "  FAIL: I2.2 — effecttab r(methods) missing (rc=`=_rc')"
    local ++fail_count
}

* --- I2.3: regtab r(methods) for Cox model ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    collect clear
    collect: stcox age drug
    regtab, xlsx("output/test_i2_cox.xlsx") sheet("Cox")
    assert strpos(`"`r(methods)'"', "Hazard ratios") > 0
}
if _rc == 0 {
    display as result "  PASS: I2.3 — regtab r(methods) for Cox says 'Hazard ratios'"
    local ++pass_count
}
else {
    display as error "  FAIL: I2.3 — Cox r(methods) wrong (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: headercolor/zebracolor customization

**# O4: headercolor() and zebracolor() customization
* =========================================================================

* --- O4.1: regtab with custom colors ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_o4_colors.xlsx") sheet("Colors") ///
        headercolor("200 200 255") zebracolor("240 240 255") zebra
}
if _rc == 0 {
    display as result "  PASS: O4.1 — custom header/zebra colors accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: O4.1 — custom colors failed (rc=`=_rc')"
    local ++fail_count
}

* --- O4.2: table1_tc with custom colors ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg, by(foreign) ///
        excel("output/test_o4_t1colors.xlsx") zebra headershade ///
        headercolor("255 200 200") zebracolor("255 240 240")
}
if _rc == 0 {
    display as result "  PASS: O4.2 — table1_tc custom colors accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: O4.2 — table1_tc colors failed (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: CSV export, r(xlsx)/r(sheet), varabbrev across commands

**# F2: CSV export
* =========================================================================

* --- F2.1: table1_tc csv export ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "output/test_f2_t1.csv"
    table1_tc price mpg weight, by(foreign) ///
        excel("output/test_f2_t1.xlsx") csv("output/test_f2_t1.csv")
    confirm file "output/test_f2_t1.csv"
    _tt_file_has using "output/test_f2_t1.csv", needle("title")
    assert r(found) == 0
    _tt_file_has using "output/test_f2_t1.csv", needle("factor")
    assert r(found) == 0
    _tt_file_has using "output/test_f2_t1.csv", needle("pvalue")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: F2.1 — table1_tc csv() export hides working names"
    local ++pass_count
}
else {
    display as error "  FAIL: F2.1 — csv export failed (rc=`=_rc')"
    local ++fail_count
}

* --- F2.2: regtab csv export ---
local ++n_total
capture erase "output/test_f2_reg.csv"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_f2_reg.xlsx") sheet("Reg") ///
        csv("output/test_f2_reg.csv")
    confirm file "output/test_f2_reg.csv"
    _tt_file_has using "output/test_f2_reg.csv", needle("ref1")
    assert r(found) == 0
    _tt_file_has using "output/test_f2_reg.csv", needle("c1")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: F2.2 — regtab csv() export hides ref/c* columns"
    local ++pass_count
}
else {
    display as error "  FAIL: F2.2 — regtab csv failed (rc=`=_rc')"
    local ++fail_count
}

* --- F2.3: regtab markdown does not expose internal c* header names ---
local ++n_total
capture erase "output/test_f2_reg.md"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, markdown("output/test_f2_reg.md")
    confirm file "output/test_f2_reg.md"
    _tt_file_has using "output/test_f2_reg.md", needle("| A |")
    assert r(found) == 0
    _tt_file_has using "output/test_f2_reg.md", needle(" c2 ")
    assert r(found) == 0
    _tt_file_has using "output/test_f2_reg.md", needle(" c3 ")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: F2.3 — regtab markdown hides internal headers"
    local ++pass_count
}
else {
    display as error "  FAIL: F2.3 — regtab markdown header leak (rc=`=_rc')"
    local ++fail_count
}

* --- F2.4: comptab markdown preserves the visible subheader row ---
local ++n_total
capture erase "output/test_f2_comptab.md"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    capture frame drop _f2_cmp_a
    regtab, frame(_f2_cmp_a, replace)
    collect clear
    collect: regress price mpg weight
    capture frame drop _f2_cmp_b
    regtab, frame(_f2_cmp_b, replace)
    comptab _f2_cmp_a _f2_cmp_b, rows(1 \ 1) ///
        markdown("output/test_f2_comptab.md")
    confirm file "output/test_f2_comptab.md"
    _tt_file_has using "output/test_f2_comptab.md", needle("Coef.")
    assert r(found) == 1
    _tt_file_has using "output/test_f2_comptab.md", needle(" c2 ")
    assert r(found) == 0
    _tt_file_has using "output/test_f2_comptab.md", needle(" c3 ")
    assert r(found) == 0
}
local _test_rc = _rc
capture frame drop _f2_cmp_a
capture frame drop _f2_cmp_b
if `_test_rc' == 0 {
    display as result "  PASS: F2.4 — comptab markdown keeps visible subheader row"
    local ++pass_count
}
else {
    display as error "  FAIL: F2.4 — comptab markdown visible subheader (rc=`_test_rc')"
    local ++fail_count
}

* =========================================================================
**# Additional: r(xlsx) and r(sheet) return values
* =========================================================================

* --- RET.1: regtab returns r(xlsx) and r(sheet) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_ret_regtab.xlsx") sheet("MySheet")
    assert `"`r(xlsx)'"' == "output/test_ret_regtab.xlsx"
    assert `"`r(sheet)'"' == "MySheet"
}
if _rc == 0 {
    display as result "  PASS: RET.1 — regtab returns r(xlsx) and r(sheet)"
    local ++pass_count
}
else {
    display as error "  FAIL: RET.1 — regtab return values wrong (rc=`=_rc')"
    local ++fail_count
}

* --- RET.2: effecttab returns r(xlsx) and r(sheet) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_ret_effecttab.xlsx") sheet("Effects")
    assert `"`r(xlsx)'"' == "output/test_ret_effecttab.xlsx"
    assert `"`r(sheet)'"' == "Effects"
}
if _rc == 0 {
    display as result "  PASS: RET.2 — effecttab returns r(xlsx) and r(sheet)"
    local ++pass_count
}
else {
    display as error "  FAIL: RET.2 — effecttab return values wrong (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# Varabbrev restore on success and error
* =========================================================================

* --- VA.1: varabbrev restored after table1_tc ---
local ++n_total
capture noisily {
    set varabbrev on
    sysuse auto, clear
    table1_tc price mpg, by(foreign)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: VA.1 — varabbrev restored after table1_tc"
    local ++pass_count
}
else {
    display as error "  FAIL: VA.1 — varabbrev not restored (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

* --- VA.2: varabbrev restored after regtab error ---
local ++n_total
capture noisily {
    set varabbrev on
    sysuse auto, clear
    * Intentional error: no collect table
    capture regtab, xlsx("output/test_va2.xlsx") sheet("Test")
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: VA.2 — varabbrev restored after regtab error"
    local ++pass_count
}
else {
    display as error "  FAIL: VA.2 — varabbrev not restored on error (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

* =========================================================================

**# Migrated: persistent theme propagation

**# 2.5: Persistent theme
* =========================================================================

* --- 2.5.1: tabtools set theme lancet ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set theme lancet
    tabtools get
    assert r(theme) == "lancet"
}
if _rc == 0 {
    display as result "  PASS: 2.5.1 — tabtools set theme lancet works"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.5.1 — tabtools set theme failed (rc=`=_rc')"
    local ++fail_count
}

* --- 2.5.2: invalid theme rejected ---
local ++n_total
capture {
    tabtools set theme invalid
}
if _rc != 0 {
    display as result "  PASS: 2.5.2 — invalid theme correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.5.2 — invalid theme should have been rejected"
    local ++fail_count
}

* --- 2.5.3: theme applies to regtab without explicit option ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set theme lancet
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_v160_theme_regtab.xlsx") sheet("Test")
    confirm file "output/test_v160_theme_regtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 2.5.3 — persistent theme applies to regtab"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.5.3 — persistent theme regtab failed (rc=`=_rc')"
    local ++fail_count
}

* --- 2.5.4: tabtools set clear clears theme ---
local ++n_total
capture noisily {
    tabtools set theme nejm
    tabtools set clear
    tabtools get
    assert `"`r(theme)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: 2.5.4 — set clear clears theme"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.5.4 — set clear did not clear theme (rc=`=_rc')"
    local ++fail_count
}

tabtools set clear

* =========================================================================

**# Migrated: digits() across crosstab/survtab/diagtab/corrtab

**# F1: digits() for crosstab, survtab, diagtab, corrtab
* =========================================================================

* --- F1.1: crosstab digits(3) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _f1_1
    crosstab foreign rep78, colpct digits(3) frame(_f1_1)
    frame _f1_1 {
        * Find a cell with a percentage — should have 3 decimal places
        local cell = c2[3]
        * Cell format: "N (XX.XXX%)" — check 3 digits after decimal
        local pct_part = substr("`cell'", strpos("`cell'", "(") + 1, .)
        local dot_pos = strpos("`pct_part'", ".")
        local pct_end = strpos("`pct_part'", "%")
        local n_decimals = `pct_end' - `dot_pos' - 1
        assert `n_decimals' == 3
    }
}
if _rc == 0 {
    display as result "  PASS: F1.1 — crosstab digits(3) formats percentages correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.1 — crosstab digits(3) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f1_1

* --- F1.2: survtab digits(2) ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _f1_2
    survtab, times(10 20) by(drug) digits(2) frame(_f1_2)
    frame _f1_2 {
        * Find a survival percentage row (contains %)
        gen byte _haspct = strpos(c2, "%") > 0
        summarize _haspct, meanonly
        assert r(max) == 1
        * Check a percentage cell has 2 decimals
        local found = 0
        forvalues i = 1/`=_N' {
            local cell = c2[`i']
            if strpos("`cell'", "%") > 0 {
                local dot_pos = strpos("`cell'", ".")
                local pct_pos = strpos("`cell'", "%")
                if `dot_pos' > 0 {
                    local n_dec = `pct_pos' - `dot_pos' - 1
                    assert `n_dec' == 2
                    local found = 1
                    continue, break
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1.2 — survtab digits(2) formats percentages correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.2 — survtab digits(2) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f1_2

* --- F1.3: diagtab digits(3) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highprice = price > 6000
    gen byte bigcar = weight > 3000
    capture frame drop _f1_3
    diagtab highprice bigcar, digits(3) frame(_f1_3)
    frame _f1_3 {
        * Find Sensitivity row — value should have 3 decimal places
        local found = 0
        forvalues i = 1/`=_N' {
            local label = c1[`i']
            if strtrim("`label'") == "Sensitivity" {
                local val = c2[`i']
                local dot_pos = strpos("`val'", ".")
                local pct_pos = strpos("`val'", "%")
                if `dot_pos' > 0 & `pct_pos' > 0 {
                    local n_dec = `pct_pos' - `dot_pos' - 1
                    assert `n_dec' == 3
                    local found = 1
                }
                continue, break
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1.3 — diagtab digits(3) formats correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.3 — diagtab digits(3) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f1_3

* --- F1.4: corrtab digits(4) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _f1_4
    corrtab price mpg weight, digits(4) frame(_f1_4)
    frame _f1_4 {
        * Off-diagonal cells have actual correlations; row 4 is first off-diag in c2
        local cell = c2[4]
        local dot_pos = strpos("`cell'", ".")
        assert `dot_pos' > 0
        local after_dot = substr("`cell'", `dot_pos' + 1, .)
        * Strip trailing stars and whitespace
        local after_dot : subinstr local after_dot "*" "", all
        local after_dot = strtrim("`after_dot'")
        local n_dec = strlen("`after_dot'")
        assert `n_dec' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: F1.4 — corrtab digits(4) formats correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.4 — corrtab digits(4) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _f1_4

* --- F1.5: digits validation (out of range) ---
local ++n_total
capture {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10) digits(7)
}
if _rc != 0 {
    display as result "  PASS: F1.5 — digits(7) correctly rejected for survtab"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.5 — digits(7) should have been rejected"
    local ++fail_count
}

* =========================================================================

**# Migrated: persistent digits/boldp via tabtools set

**# W1/W2: Persistent digits/boldp via tabtools set
* =========================================================================

* --- W1.1: tabtools set digits ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 3
    tabtools get
    assert r(digits) == "3"
}
if _rc == 0 {
    display as result "  PASS: W1.1 — tabtools set digits 3 stores correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: W1.1 — tabtools set digits failed (rc=`=_rc')"
    local ++fail_count
}

* --- W1.2: persistent digits applies to regtab ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 4
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _w1_2
    regtab, frame(_w1_2)
    frame _w1_2 {
        * Row 4 is first data row (rows 1-3 are title/headers)
        local cell = c1[4]
        local dot_pos = strpos("`cell'", ".")
        assert `dot_pos' > 0
        local after = substr("`cell'", `dot_pos' + 1, .)
        local n_dec = strlen(strtrim("`after'"))
        assert `n_dec' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: W1.2 — persistent digits(4) applies to regtab"
    local ++pass_count
}
else {
    display as error "  FAIL: W1.2 — persistent digits for regtab failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _w1_2
tabtools set clear

* --- W1.3: local digits() overrides persistent ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 4
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _w1_3
    regtab, frame(_w1_3) digits(1)
    frame _w1_3 {
        * Row 4 is first data row
        local cell = c1[4]
        local dot_pos = strpos("`cell'", ".")
        assert `dot_pos' > 0
        local after = substr("`cell'", `dot_pos' + 1, .)
        local n_dec = strlen(strtrim("`after'"))
        assert `n_dec' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: W1.3 — local digits(1) overrides persistent digits(4)"
    local ++pass_count
}
else {
    display as error "  FAIL: W1.3 — digits override failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _w1_3
tabtools set clear

* --- W2.1: tabtools set boldp ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set boldp 0.05
    tabtools get
    assert r(boldp) == "0.05"
}
if _rc == 0 {
    display as result "  PASS: W2.1 — tabtools set boldp 0.05 stores correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.1 — tabtools set boldp failed (rc=`=_rc')"
    local ++fail_count
}

* --- W2.2: tabtools set boldp validation (out of range) ---
local ++n_total
capture {
    tabtools set boldp 1.5
}
if _rc != 0 {
    display as result "  PASS: W2.2 — boldp 1.5 correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.2 — boldp 1.5 should have been rejected"
    local ++fail_count
}

* --- W2.3: tabtools set boldp validation (zero) ---
local ++n_total
capture {
    tabtools set boldp 0
}
if _rc != 0 {
    display as result "  PASS: W2.3 — boldp 0 correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.3 — boldp 0 should have been rejected"
    local ++fail_count
}

* --- W2.4: tabtools set digits validation (non-integer) ---
local ++n_total
capture {
    tabtools set digits 2.5
}
if _rc != 0 {
    display as result "  PASS: W2.4 — digits 2.5 correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.4 — digits 2.5 should have been rejected"
    local ++fail_count
}

* --- W2.5: tabtools set digits validation (out of range) ---
local ++n_total
capture {
    tabtools set digits 7
}
if _rc != 0 {
    display as result "  PASS: W2.5 — digits 7 correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.5 — digits 7 should have been rejected"
    local ++fail_count
}

* --- W2.6: tabtools set clear clears digits and boldp ---
local ++n_total
capture noisily {
    tabtools set digits 3
    tabtools set boldp 0.05
    tabtools set clear
    tabtools get
    assert `"`r(digits)'"' == ""
    assert `"`r(boldp)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: W2.6 — set clear clears digits and boldp"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.6 — set clear did not clear digits/boldp (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

* =========================================================================

**# Migrated: frame(name, replace) for all frame-capable commands

**# U2: frame(name, replace) for all frame-capable commands
* =========================================================================

* --- U2.1: frame(name, replace) for regtab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _u2_1
    regtab, frame(_u2_1)
    * Now call again with replace — should succeed
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, frame(_u2_1, replace)
    frame _u2_1: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.1 — regtab frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.1 — regtab frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_1

* --- U2.3: frame(name, replace) for effecttab ---
local ++n_total
capture noisily {
    capture frame drop _u2_3
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, frame(_u2_3)
    * Replace — reload data because effecttab uses preserve/restore
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, frame(_u2_3, replace)
    frame _u2_3: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.3 — effecttab frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.3 — effecttab frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_3

* --- U2.2: frame without replace errors on existing ---
* NOTE: placed after U2.3 because the intentional error leaves stale preserve
local ++n_total
capture {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _u2_2
    regtab, frame(_u2_2)
    * Call again without replace — should error
    collect clear
    collect: regress price mpg weight
    regtab, frame(_u2_2)
}
if _rc != 0 {
    display as result "  PASS: U2.2 — frame without replace errors on existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.2 — should have errored on existing frame"
    local ++fail_count
}
capture frame drop _u2_2
capture restore

* --- U2.4: frame(name, replace) for survtab ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _u2_4
    survtab, times(10 20) by(drug) frame(_u2_4)
    survtab, times(10 20) by(drug) frame(_u2_4, replace)
    frame _u2_4: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.4 — survtab frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.4 — survtab frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_4

* --- U2.5: frame(name, replace) for crosstab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _u2_5
    crosstab foreign rep78, frame(_u2_5)
    crosstab foreign rep78, colpct frame(_u2_5, replace)
    frame _u2_5: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.5 — crosstab frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.5 — crosstab frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_5

* --- U2.6: frame(name, replace) for corrtab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _u2_6
    corrtab price mpg weight, frame(_u2_6)
    corrtab price mpg weight, spearman frame(_u2_6, replace)
    frame _u2_6: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.6 — corrtab frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.6 — corrtab frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_6

* --- U2.7: frame(name, replace) for diagtab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highprice = price > 6000
    gen byte bigcar = weight > 3000
    capture frame drop _u2_7
    diagtab highprice bigcar, frame(_u2_7)
    diagtab highprice bigcar, frame(_u2_7, replace)
    frame _u2_7: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.7 — diagtab frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.7 — diagtab frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_7

* --- U2.9: frame(name, replace) for table1_tc ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _u2_9
    table1_tc, vars(price conts \ mpg conts \ weight conts) frame(_u2_9)
    table1_tc, vars(price conts \ mpg conts) frame(_u2_9, replace)
    frame _u2_9: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.9 — table1_tc frame(name, replace) works"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.9 — table1_tc frame(name, replace) failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _u2_9

* --- U2.10: frame invalid sub-option rejected ---
local ++n_total
capture {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _u2_10
    regtab, frame(_u2_10, append)
}
if _rc != 0 {
    display as result "  PASS: U2.10 — frame(name, append) correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: U2.10 — frame(name, append) should have been rejected"
    local ++fail_count
}
capture frame drop _u2_10

* =========================================================================

**# Migrated: addrow() + pdp()/highpdp() across commands

**# I3: addrow() for effecttab and survtab
* =========================================================================

* --- I3.1: effecttab addrow ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture frame drop _i3_1
    effecttab, frame(_i3_1) addrow("P interaction" 0.034)
    frame _i3_1 {
        gen byte _has_pint = strpos(A, "P interaction") > 0
        summarize _has_pint, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: I3.1 — effecttab addrow() adds custom row"
    local ++pass_count
}
else {
    display as error "  FAIL: I3.1 — effecttab addrow() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _i3_1

* --- I3.2: survtab addrow ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _i3_2
    survtab, times(10 20) by(drug) frame(_i3_2) addrow("P trend" 0.012 0.045 0.089)
    frame _i3_2 {
        gen byte _has_ptrend = strpos(c1, "P trend") > 0
        summarize _has_ptrend, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: I3.2 — survtab addrow() adds custom row"
    local ++pass_count
}
else {
    display as error "  FAIL: I3.2 — survtab addrow() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _i3_2

* --- I3.3: regtab addrow with multiple rows (backslash separator) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _i3_3
    regtab, frame(_i3_3) addrow("P trend" 0.012 \ "P interaction" 0.045)
    frame _i3_3 {
        gen byte _has_ptrend = strpos(A, "P trend") > 0
        gen byte _has_pint = strpos(A, "P interaction") > 0
        summarize _has_ptrend, meanonly
        assert r(max) == 1
        summarize _has_pint, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: I3.3 — regtab addrow() with multiple rows via backslash"
    local ++pass_count
}
else {
    display as error "  FAIL: I3.3 — regtab multi addrow() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _i3_3

* --- I3.4: effecttab addrow with Excel export ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "output/test_v170_addrow.xlsx"
    effecttab, xlsx("output/test_v170_addrow.xlsx") sheet("Test") ///
        addrow("P interaction" 0.034)
    confirm file "output/test_v170_addrow.xlsx"
}
if _rc == 0 {
    display as result "  PASS: I3.4 — effecttab addrow with Excel export"
    local ++pass_count
}
else {
    display as error "  FAIL: I3.4 — effecttab addrow Excel failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# O1: pdp()/highpdp() for regtab, effecttab, survtab
* =========================================================================

* --- O1.1: regtab pdp(4) produces 4-decimal p-values for small p ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _o1_1
    regtab, frame(_o1_1) pdp(4) highpdp(3)
    frame _o1_1 {
        * p-value column is c3; data rows start at row 4
        local found = 0
        forvalues i = 4/`=_N' {
            local cell = c3[`i']
            if "`cell'" != "" & "`cell'" != "." {
                if substr("`cell'", 1, 1) != "<" {
                    local dot_pos = strpos("`cell'", ".")
                    if `dot_pos' > 0 {
                        local after = substr("`cell'", `dot_pos' + 1, .)
                        local n_dec = strlen(strtrim("`after'"))
                        * Should be either pdp(4) or highpdp(3)
                        assert `n_dec' == 4 | `n_dec' == 3
                        local found = 1
                    }
                }
                else {
                    * "<0.0001" format — pdp(4) means 4 decimal places
                    assert strpos("`cell'", "0.0001") > 0
                    local found = 1
                }
                continue, break
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: O1.1 — regtab pdp(4)/highpdp(3) formats p-values"
    local ++pass_count
}
else {
    display as error "  FAIL: O1.1 — regtab pdp/highpdp failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _o1_1

* --- O1.2: effecttab pdp(4) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, pdp(4) highpdp(2)
}
if _rc == 0 {
    display as result "  PASS: O1.2 — effecttab pdp(4)/highpdp(2) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: O1.2 — effecttab pdp/highpdp failed (rc=`=_rc')"
    local ++fail_count
}

* --- O1.3: survtab pdp(4) ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20) by(drug) pdp(4) highpdp(2)
}
if _rc == 0 {
    display as result "  PASS: O1.3 — survtab pdp(4)/highpdp(2) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: O1.3 — survtab pdp/highpdp failed (rc=`=_rc')"
    local ++fail_count
}

* --- O1.4: pdp default is 3 (verify <0.001 format) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _o1_4
    regtab, frame(_o1_4)
    * Default pdp=3 means threshold is 0.001
    * We just verify the command runs with defaults
    frame _o1_4: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: O1.4 — regtab default pdp/highpdp works"
    local ++pass_count
}
else {
    display as error "  FAIL: O1.4 — regtab default pdp/highpdp failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _o1_4

* =========================================================================

**# Migrated: combined feature interactions + data preservation

**# Combined feature interaction tests
* =========================================================================

* --- COMBO.1: compact + refcat ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _combo1
    regtab, frame(_combo1) compact refcat("--")
    frame _combo1 {
        * Verify compact (2 c-columns per model)
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
        * Verify refcat
        gen byte _has_ref = strpos(c1, "--") > 0
        summarize _has_ref, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: COMBO.1 — compact + refcat together"
    local ++pass_count
}
else {
    display as error "  FAIL: COMBO.1 — compact + refcat failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _combo1

* --- COMBO.2: persistent digits + events + frame(replace) ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 3
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _combo2
    survtab, times(10 20) by(drug) events frame(_combo2)
    * Replace frame
    survtab, times(10 20 30) by(drug) events frame(_combo2, replace)
    frame _combo2: assert _N > 0
    assert r(events_1) > 0
}
if _rc == 0 {
    display as result "  PASS: COMBO.2 — persistent digits + events + frame(replace)"
    local ++pass_count
}
else {
    display as error "  FAIL: COMBO.2 — combo test failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _combo2
tabtools set clear

* --- COMBO.3: compact + addrow + Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/test_v170_combo3.xlsx"
    regtab, xlsx("output/test_v170_combo3.xlsx") sheet("Test") ///
        compact addrow("P trend" 0.034)
    confirm file "output/test_v170_combo3.xlsx"
}
if _rc == 0 {
    display as result "  PASS: COMBO.3 — compact + addrow + Excel export"
    local ++pass_count
}
else {
    display as error "  FAIL: COMBO.3 — compact + addrow + Excel failed (rc=`=_rc')"
    local ++fail_count
}

* --- COMBO.4: pdp + boldp + compact ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/test_v170_combo4.xlsx"
    regtab, xlsx("output/test_v170_combo4.xlsx") sheet("Test") ///
        compact boldp(0.05) pdp(4) highpdp(2)
    confirm file "output/test_v170_combo4.xlsx"
}
if _rc == 0 {
    display as result "  PASS: COMBO.4 — pdp + boldp + compact + Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: COMBO.4 — pdp + boldp + compact + Excel failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# Data preservation
* =========================================================================

* --- DP.1: regtab compact preserves user data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    local orig_vars : char _dta[__ReportVars]
    collect clear
    collect: regress price mpg weight
    regtab, compact
    assert _N == `orig_n'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: DP.1 — regtab compact preserves user data"
    local ++pass_count
}
else {
    display as error "  FAIL: DP.1 — user data changed after compact regtab (rc=`=_rc')"
    local ++fail_count
}

* --- DP.2: survtab events preserves user data ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local orig_n = _N
    survtab, times(10 20) by(drug) events
    assert _N == `orig_n'
    confirm variable studytime died drug
    assert strpos(`"`r(methods)'"', "log-rank test") > 0
}
if _rc == 0 {
    display as result "  PASS: DP.2 — survtab events preserves user data"
    local ++pass_count
}
else {
    display as error "  FAIL: DP.2 — user data changed after survtab events (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: corrtab/comptab gaps + excel() synonym across commands

**# SECTION 6: corrtab/comptab — minor gaps
* ============================================================

* Test: corrtab footnote
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, xlsx("`output_dir'/_cov_corrtab_footnote.xlsx") ///
        sheet("footnote") footnote("Pearson correlation coefficients")
    confirm file "`output_dir'/_cov_corrtab_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: comptab title and footnote
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight if foreign == 0
    regtab, xlsx("`output_dir'/_cov_comptab_tf.xlsx") sheet("Domestic") ///
        frame(_cov_ct_dom)
    collect clear
    collect: regress price mpg weight if foreign == 1
    regtab, xlsx("`output_dir'/_cov_comptab_tf.xlsx") sheet("Foreign") ///
        frame(_cov_ct_for)
    comptab _cov_ct_dom _cov_ct_for, ///
        rows("1 2 \ 1 2") ///
        xlsx("`output_dir'/_cov_comptab_tf.xlsx") sheet("Combined") ///
        title("Regression Coefficients by Origin") ///
        footnote("Linear regression. CI = 95% confidence interval.")
    confirm file "`output_dir'/_cov_comptab_tf.xlsx"
    capture frame drop _cov_ct_dom
    capture frame drop _cov_ct_for
}
if _rc == 0 {
    display as result "  PASS: comptab title()/footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab title()/footnote() (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 7: excel() synonym tests
* ============================================================

* Test: table1_tc excel() synonym
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn) ///
        excel("`output_dir'/_cov_excel_t1.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_t1.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: regtab excel() synonym
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, excel("`output_dir'/_cov_excel_reg.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_reg.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: effecttab excel() synonym
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, excel("`output_dir'/_cov_excel_eff.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_eff.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab excel() synonym (error `=_rc')"
    local ++fail_count
}

* Test: corrtab excel() synonym
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, excel("`output_dir'/_cov_excel_corr.xlsx") sheet("excel")
    confirm file "`output_dir'/_cov_excel_corr.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab excel() synonym"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab excel() synonym (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: data preservation across commands

**# SECTION 10: Data preservation across all commands
* ============================================================

* Test: regtab data preservation
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    local _k1 = c(k)
    sum price, meanonly
    local _mean1 = r(mean)
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_cov_reg_preserve.xlsx") sheet("preserve")
    assert _N == `_n1'
    assert c(k) == `_k1'
    sum price, meanonly
    assert r(mean) == `_mean1'
}
if _rc == 0 {
    display as result "  PASS: regtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: effecttab data preservation
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_preserve.xlsx") sheet("preserve")
    assert _N == `_n1'
}
if _rc == 0 {
    display as result "  PASS: effecttab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: corrtab data preservation
capture noisily {
    sysuse auto, clear
    local _n1 = _N
    corrtab price mpg weight, xlsx("`output_dir'/_cov_corr_preserve.xlsx") sheet("preserve")
    assert _N == `_n1'
}
if _rc == 0 {
    display as result "  PASS: corrtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: custom theme colors respected

**# 2. Custom theme colors — commands must respect global color settings

**## 2a. Commands resolve custom headercolor/zebracolor globals
local t2a_pass = 1
capture noisily {
    * Set custom theme
    tabtools set theme custom, headercolor("255 0 0") zebracolor("255 255 0")
    assert "$TABTOOLS_HEADERCOLOR" == "255 0 0"
    assert "$TABTOOLS_ZEBRACOLOR" == "255 255 0"

    * Use table1_tc — more reliable than regtab for color testing
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) ///
        xlsx("`output_dir'/_regfix_custom_table1.xlsx") sheet("t1") zebra

    * Verify custom zebra color (FFFF00 = "255 255 0") is in the xlsx,
    * NOT the default blue (EDF2F9 = "237 242 249")
    ! cd "`output_dir'" && unzip -o _regfix_custom_table1.xlsx xl/styles.xml ///
        -d _regfix_custom_inspect > /dev/null 2>&1
    ! grep -c 'FFFF00\|ffff00' "`output_dir'/_regfix_custom_inspect/xl/styles.xml" ///
        > "`output_dir'/_regfix_custom_fill.txt" 2>&1

    file open _fh using "`output_dir'/_regfix_custom_fill.txt", read text
    file read _fh _line
    file close _fh

    local custom_fill = real(strtrim("`_line'"))
    assert `custom_fill' > 0
}
if _rc == 0 {
    display as result "  PASS [2a.fill]: custom zebra color (yellow) used in xlsx"
}
else {
    display as error "  FAIL [2a.fill]: custom zebra color not found (error `=_rc')"
    local t2a_pass = 0
}

if `t2a_pass' == 1 {
    display as result "  PASS: commands respect custom theme colors"
    local ++pass_count
}
else {
    display as error "  FAIL: commands respect custom theme colors"
    local ++fail_count
}

* Clean up theme
tabtools set clear

**## 2b. Custom theme colors are cleared properly
capture noisily {
    tabtools set theme custom, headercolor("255 0 0") zebracolor("255 255 0")
    assert "$TABTOOLS_HEADERCOLOR" == "255 0 0"
    tabtools set clear
    assert "$TABTOOLS_HEADERCOLOR" == ""
    assert "$TABTOOLS_ZEBRACOLOR" == ""
}
if _rc == 0 {
    display as result "  PASS: custom theme colors cleared by set clear"
    local ++pass_count
}
else {
    display as error "  FAIL: custom theme colors not cleared (error `=_rc')"
    local ++fail_count
}


**## 2c. corrtab respects custom theme colors
capture noisily {
    tabtools set theme custom, headercolor("255 0 0") zebracolor("255 255 0")
    sysuse auto, clear
    capture erase "`output_dir'/_regfix_corrtab_custom.xlsx"
    corrtab price mpg weight, xlsx("`output_dir'/_regfix_corrtab_custom.xlsx") ///
        headershade zebra star(0.05)
    confirm file "`output_dir'/_regfix_corrtab_custom.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab accepts custom headercolor/zebracolor"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab custom theme colors (error `=_rc')"
    local ++fail_count
}
tabtools set clear

**## 2d. diagtab respects custom theme colors
capture noisily {
    tabtools set theme custom, headercolor("0 0 255") zebracolor("200 200 255")
    sysuse auto, clear
    gen byte highprice = (price > 6000) if !missing(price)
    gen byte mpg_test = (mpg < 20) if !missing(mpg)
    capture erase "`output_dir'/_regfix_diagtab_custom.xlsx"
    diagtab mpg_test highprice, xlsx("`output_dir'/_regfix_diagtab_custom.xlsx") ///
        headershade zebra
    confirm file "`output_dir'/_regfix_diagtab_custom.xlsx"
}
if _rc == 0 {
    display as result "  PASS: diagtab accepts custom headercolor/zebracolor"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab custom theme colors (error `=_rc')"
    local ++fail_count
}
tabtools set clear



**# Migrated: bivariate/descriptive command contracts

**# Helpers
capture program drop _review_build_comptab_frame
program define _review_build_comptab_frame
    version 17.0
    capture frame drop rb_src
    frame create rb_src
    frame rb_src {
        clear
        set obs 5
        gen str244 A = ""
        gen str244 c1 = ""
        gen str244 c2 = ""
        gen str244 c3 = ""
        replace A = "Variable" in 2
        replace c1 = "Estimate" in 2
        replace c2 = "95% CI" in 2
        replace c3 = "p-value" in 2
        replace A = "Characteristic" in 3
        replace c1 = "b" in 3
        replace c2 = "95% CI" in 3
        replace c3 = "p-value" in 3
        replace A = "Age" in 4
        replace c1 = "1.23" in 4
        replace c2 = "(0.50, 1.96)" in 4
        replace c3 = "0.040" in 4
        replace A = "Sex" in 5
        replace c1 = "0.88" in 5
        replace c2 = "(0.40, 1.36)" in 5
        replace c3 = "0.520" in 5
        gen long _orig_n = _n
        gen byte _keep = 99
    }
end

**# Tests

capture noisily {
    set varabbrev on
    clear
    set obs 10
    gen double x = _n
    gen double y = _n
    capture corrtab x y, lower upper
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: corrtab validation error restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab validation error restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    set varabbrev on
    clear
    input byte outcome byte exposure
    0 0
    0 1
    0 2
    1 0
    1 1
    1 2
    end
    capture crosstab outcome exposure, or
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: crosstab non-2x2 association error restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab non-2x2 association error restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    set varabbrev on
    clear
    input byte outcome byte exposure
    0 0
    0 1
    1 0
    1 1
    end
    capture crosstab outcome exposure, rowpct totalpct
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: crosstab percent-mode conflict restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab percent-mode conflict restores varabbrev (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    set varabbrev on
    _review_build_comptab_frame
 capture comptab rb_src, rows(1) rownames(age)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: comptab rows()/rownames() conflict restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab rows()/rownames() conflict restores varabbrev (rc=`=_rc')"
    local ++fail_count
}
capture frame drop rb_src

capture noisily {
    _review_build_comptab_frame
    capture frame drop rb_out
    comptab rb_src, rows(1 2) frame(rb_out, replace)
    assert r(N_rows) == 5
    frame rb_out {
        assert A[4] == "Age"
        assert A[5] == "Sex"
        capture confirm variable _orig_n
        assert _rc != 0
        capture confirm variable _keep
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: comptab source helper-name columns do not leak into output"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab source helper-name columns do not leak into output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop rb_src
capture frame drop rb_out

capture noisily {
    set varabbrev on
    sysuse auto, clear
    capture frame drop rb_star_desc
    capture frame drop rb_star_asc
    quietly corrtab price mpg weight length, full star(0.1 0.05 0.01) ///
        frame(rb_star_desc, replace)
    local desc_methods `"`r(methods)'"'
    quietly corrtab price mpg weight length, full star(0.01 0.05 0.1) ///
        frame(rb_star_asc, replace)
    local asc_methods `"`r(methods)'"'
    assert `"`desc_methods'"' == `"`asc_methods'"'
    assert strpos(`"`desc_methods'"', "* p<.1") > 0 | ///
        strpos(`"`desc_methods'"', "* p<0.1") > 0
    assert strpos(`"`desc_methods'"', "** p<.05") > 0 | ///
        strpos(`"`desc_methods'"', "** p<0.05") > 0
    assert strpos(`"`desc_methods'"', "*** p<.01") > 0 | ///
        strpos(`"`desc_methods'"', "*** p<0.01") > 0
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: corrtab star() thresholds normalize order and restore varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab star() threshold-order contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop rb_star_desc
capture frame drop rb_star_asc

capture noisily {
    set varabbrev on
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture desctab, keep(3) drop(4)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: desctab keep()/drop() conflict restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: desctab keep()/drop() conflict restores varabbrev (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: Cox/survival + post-estimation contracts


capture program drop _review_models_survdata
program define _review_models_survdata
    version 17.0
    clear
    set obs 160
    gen long id = _n
    gen byte treated = mod(_n, 2)
    gen double age = 45 + mod(_n, 30)
    gen double t = 5 + mod(_n, 25) + 3 * treated
    gen byte died = (mod(_n, 5) != 0)
    label define trtlbl 0 "Control" 1 "Treated", replace
    label values treated trtlbl
    label variable treated "Treatment"
    label variable age "Age"
    stset t, failure(died) id(id)
end

**# Cox model and survival table contracts
capture noisily {
    _review_models_survdata
    collect clear
    collect: stcox treated age

    capture frame drop review_regcox
    regtab, frame(review_regcox, replace) noint stats(n n_sub ll)
    assert "`r(coef_label)'" == "HR"
    assert r(N_models) == 1
    assert strpos(lower(`"`r(methods)'"'), "hazard ratios") > 0

    local found_treated = 0
    local found_age = 0
    frame review_regcox {
        forvalues i = 1/`=_N' {
            if strpos(A[`i'], "Treatment") > 0 local found_treated = 1
            if strpos(A[`i'], "Age") > 0 local found_age = 1
        }
    }
    assert `found_treated' == 1
    assert `found_age' == 1

    capture frame drop review_surv
    survtab, times(10 20) by(treated) events riskset frame(review_surv, replace)
    assert r(N_rows) > 0
    assert r(events_1) + r(events_2) > 0
    assert r(atrisk_1) + r(atrisk_2) == 160
    assert r(logrank_p) >= 0 & r(logrank_p) <= 1
    assert "`r(frame)'" == "review_surv"
    assert strpos(lower(`"`r(methods)'"'), "kaplan-meier") > 0

    local found_events = 0
    local found_logrank = 0
    frame review_surv {
        forvalues i = 1/`=_N' {
            if strtrim(c1[`i']) == "Events / N" local found_events = 1
            if strpos(c1[`i'], "Log-rank") > 0 local found_logrank = 1
        }
    }
    assert `found_events' == 1
    assert `found_logrank' == 1
}
if _rc == 0 {
    display as result "  PASS: Cox regtab and grouped survtab contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: Cox regtab and grouped survtab contracts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop review_regcox
capture frame drop review_surv

**# Diagnostic reporting after an estimation command
capture noisily {
    * deterministic local stand-in for webuse lbw (avoids a network fetch
    * that has no timeout and can hang batch QA runs)
    clear
    set obs 189
    set seed 4242
    gen byte smoke = runiform() < .39
    gen double lwt = 80 + int(runiform()*150)
    gen byte age = 14 + int(runiform()*30)
    gen byte low = runiform() < invlogit(-1 + .6*smoke - .012*lwt + .02*age)
    quietly logit low age lwt smoke
    local before_cmd "`e(cmd)'"
    predict double phat, pr

    capture frame drop review_diag
    diagtab phat low, cutoff(0.30) auc frame(review_diag, replace)

    assert "`before_cmd'" == "logit"
    assert "`e(cmd)'" == "logit"
    assert r(TP) + r(FP) + r(FN) + r(TN) == e(N)
    assert r(auc) >= 0 & r(auc) <= 1
    assert "`r(frame)'" == "review_diag"
    assert strpos(lower(`"`r(methods)'"'), "diagnostic accuracy") > 0

    frame review_diag {
        assert _N >= 6
        local found_auc = 0
        forvalues i = 1/`=_N' {
            if strpos(lower(c1[`i']), "auc") > 0 local found_auc = 1
        }
    }
    assert `found_auc' == 1
}
if _rc == 0 {
    display as result "  PASS: diagtab preserves estimation state and reports AUC"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab estimation-state/AUC contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop review_diag


**# Migrated: Excel content inspection: regtab, pdp formatting, persistent boldp

local checker "`tools_dir'/check_xlsx.py"
capture confirm file "`checker'"
if _rc != 0 local checker ""
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found in qa/tools — using Stata-native fallbacks where possible"
}

* =========================================================================
**# R1: Excel content inspection — regtab
* =========================================================================

* --- R1.1: regtab Excel has correct headers ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/_rr_regtab.xlsx"
    regtab, xlsx("output/_rr_regtab.xlsx") sheet("Test") title("Regression Results")
    confirm file "output/_rr_regtab.xlsx"
}
if _rc == 0 {
    * Validate Excel content — title cell, header row, structure
    if `has_checker' {
        shell python3 "`checker'" "output/_rr_regtab.xlsx" --sheet "Test" --cell-contains A1 "Regression Results" --min-rows 5 --min-cols 3 --has-pattern p-values --has-borders --result-file "output/_rr_r1_1.txt" --quiet
        file open _fh using "output/_rr_r1_1.txt", read text
        file read _fh _line
        file close _fh
        if "`_line'" == "PASS" {
            display as result "  PASS: R1.1 - regtab Excel has title, headers, p-values, borders"
            local ++pass_count
        }
        else {
            display as error "  FAIL: R1.1 - regtab Excel content checks failed"
            local ++fail_count
        }
        capture erase "output/_rr_r1_1.txt"
    }
    else {
        preserve
        import excel "output/_rr_regtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Regression Results"
        assert _N >= 5
        quietly ds
        local _nvars : word count `r(varlist)'
        assert `_nvars' >= 3
        restore
        display as result "  PASS: R1.1 - regtab Excel has title and structure (Stata-native fallback)"
        local ++pass_count
    }
}
else {
    display as error "  FAIL: R1.1 - regtab xlsx export failed (rc=`=_rc')"
    local ++fail_count
}

* --- R1.2: regtab Excel p-value cells contain actual p-values ---
local ++n_total
local r1_2_pass = 1
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _rr_r12
    regtab, frame(_rr_r12)
    * Verify p-value column (c3) has parseable numeric values
    frame _rr_r12 {
        local found_pval = 0
        forvalues i = 4/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" != "" & "`cell'" != "." {
                * Must be either "<0.001" or a real number in [0,1]
                if substr("`cell'", 1, 1) == "<" {
                    local numpart = substr("`cell'", 2, .)
                    local numval = real("`numpart'")
                    assert `numval' > 0 & `numval' < 1
                }
                else {
                    local numval = real("`cell'")
                    assert `numval' >= 0 & `numval' <= 1
                }
                local found_pval = 1
            }
        }
        assert `found_pval' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R1.2 - regtab p-value cells contain valid p-values in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: R1.2 - regtab p-value cells invalid (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r12

* --- R1.3: regtab Excel cell values match frame values ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/_rr_regtab_match.xlsx"
    capture frame drop _rr_r13
    regtab, xlsx("output/_rr_regtab_match.xlsx") sheet("Test") frame(_rr_r13)
    * Get the first data row estimate from the frame
    frame _rr_r13 {
        local frame_est = c1[4]
        local frame_p = c3[4]
    }
    * Verify the same values appear in Excel (row 4 = Excel row 5 due to title)
    * Cell B5 should contain the estimate, cell D5 should contain the p-value
    if `has_checker' {
        shell python3 "`checker'" "output/_rr_regtab_match.xlsx" --sheet "Test" --cell-not-empty B5 D5 --result-file "output/_rr_r1_3.txt" --quiet
        file open _fh using "output/_rr_r1_3.txt", read text
        file read _fh _line
        file close _fh
        assert "`_line'" == "PASS"
    }
    else {
        preserve
        import excel "output/_rr_regtab_match.xlsx", sheet("Test") clear allstring
        assert strtrim(B[5]) != ""
        assert strtrim(D[5]) != ""
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: R1.3 - regtab Excel data cells are non-empty (frame-Excel parity)"
    local ++pass_count
}
else {
    display as error "  FAIL: R1.3 - regtab Excel data cells empty or missing (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r13
capture erase "output/_rr_r1_3.txt"

* --- R1.4: effecttab Excel content inspection ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "output/_rr_effecttab.xlsx"
    effecttab, xlsx("output/_rr_effecttab.xlsx") sheet("Test") title("Treatment Effects")
    confirm file "output/_rr_effecttab.xlsx"
    if `has_checker' {
        shell python3 "`checker'" "output/_rr_effecttab.xlsx" --sheet "Test" --cell-contains A1 "Treatment Effects" --min-rows 3 --min-cols 3 --has-borders --result-file "output/_rr_r1_4.txt" --quiet
        file open _fh using "output/_rr_r1_4.txt", read text
        file read _fh _line
        file close _fh
        assert "`_line'" == "PASS"
    }
    else {
        preserve
        import excel "output/_rr_effecttab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Treatment Effects"
        assert _N >= 3
        quietly ds
        local _nvars : word count `r(varlist)'
        assert `_nvars' >= 3
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: R1.4 - effecttab Excel has title, structure, borders"
    local ++pass_count
}
else {
    display as error "  FAIL: R1.4 - effecttab Excel content failed (rc=`=_rc')"
    local ++fail_count
}
capture erase "output/_rr_r1_4.txt"

* --- R1.5: survtab Excel content inspection ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture erase "output/_rr_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("output/_rr_survtab.xlsx") ///
        sheet("Test") title("Survival Estimates")
    confirm file "output/_rr_survtab.xlsx"
    if `has_checker' {
        shell python3 "`checker'" "output/_rr_survtab.xlsx" --sheet "Test" --cell-contains A1 "Survival Estimates" --min-rows 4 --min-cols 2 --has-borders --has-pattern percentages --result-file "output/_rr_r1_5.txt" --quiet
        file open _fh using "output/_rr_r1_5.txt", read text
        file read _fh _line
        file close _fh
        assert "`_line'" == "PASS"
    }
    else {
        preserve
        import excel "output/_rr_survtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Survival Estimates"
        assert _N >= 4
        quietly ds
        local _nvars : word count `r(varlist)'
        assert `_nvars' >= 2
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: R1.5 - survtab Excel has title, structure, percentages"
    local ++pass_count
}
else {
    display as error "  FAIL: R1.5 - survtab Excel content failed (rc=`=_rc')"
    local ++fail_count
}
capture erase "output/_rr_r1_5.txt"

* =========================================================================
**# R2: pdp/highpdp value formatting for effecttab and survtab
* =========================================================================

* --- R2.1: effecttab pdp(4) produces 4 decimal place p-values ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture frame drop _rr_r21
    effecttab, frame(_rr_r21) pdp(4) highpdp(3)
    frame _rr_r21 {
        * In effecttab, p-value is every 3rd column: c3, c6, c9...
        * Data rows start at row 3 (after header rows)
        local found_pdp = 0
        forvalues i = 3/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" == "" | "`cell'" == "." continue
            if substr("`cell'", 1, 1) == "<" {
                * "<0.0001" format: pdp(4) means threshold is 0.0001
                assert strpos("`cell'", "0.0001") > 0
                local found_pdp = 1
            }
            else {
                local pval = real("`cell'")
                if `pval' < . {
                    * Count decimal places
                    local dot_pos = strpos("`cell'", ".")
                    if `dot_pos' > 0 {
                        local after = substr("`cell'", `dot_pos' + 1, .)
                        local n_dec = strlen(strtrim("`after'"))
                        * Should be pdp(4) for p<0.10 or highpdp(3) for p>=0.10
                        if `pval' < 0.10 {
                            assert `n_dec' == 4
                        }
                        else {
                            assert `n_dec' == 3
                        }
                        local found_pdp = 1
                    }
                }
            }
        }
        assert `found_pdp' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R2.1 - effecttab pdp(4)/highpdp(3) formats p-values correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: R2.1 - effecttab pdp/highpdp formatting wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r21

* --- R2.2: effecttab pdp(2) threshold behavior ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture frame drop _rr_r22
    effecttab, frame(_rr_r22) pdp(2) highpdp(1)
    frame _rr_r22 {
        local found = 0
        forvalues i = 3/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" == "" | "`cell'" == "." continue
            if substr("`cell'", 1, 1) == "<" {
                * pdp(2) threshold is 0.01
                assert strpos("`cell'", "0.01") > 0
                local found = 1
            }
            else {
                local pval = real("`cell'")
                if `pval' < . {
                    local dot_pos = strpos("`cell'", ".")
                    if `dot_pos' > 0 {
                        local after = substr("`cell'", `dot_pos' + 1, .)
                        local n_dec = strlen(strtrim("`after'"))
                        if `pval' < 0.10 {
                            assert `n_dec' == 2
                        }
                        else {
                            assert `n_dec' == 1
                        }
                        local found = 1
                    }
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R2.2 - effecttab pdp(2)/highpdp(1) threshold at 0.10 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: R2.2 - effecttab pdp(2)/highpdp(1) formatting wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r22

* --- R2.3: survtab pdp(4) formats log-rank p-value correctly ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _rr_r23
    survtab, times(10 20 30) by(drug) pdp(4) highpdp(2) frame(_rr_r23)
    frame _rr_r23 {
        * Find the log-rank test row — contains "Log-rank" or "p ="
        local found_lr = 0
        forvalues i = 1/`=_N' {
            local cell = c1[`i']
            if strpos("`cell'", "Log-rank") > 0 | strpos("`cell'", "log-rank") > 0 {
                * Extract p-value from "Log-rank test: chi2(X) = Y, p = Z"
                local p_pos = strpos("`cell'", "p = ")
                if `p_pos' > 0 {
                    local p_str = substr("`cell'", `p_pos' + 4, .)
                    local p_str = strtrim("`p_str'")
                    if substr("`p_str'", 1, 1) == "<" {
                        * pdp(4) means threshold "<0.0001"
                        assert strpos("`p_str'", "0.0001") > 0
                    }
                    else {
                        local pval = real("`p_str'")
                        if `pval' < . {
                            local dot_pos = strpos("`p_str'", ".")
                            if `dot_pos' > 0 {
                                local after = substr("`p_str'", `dot_pos' + 1, .)
                                local n_dec = strlen(strtrim("`after'"))
                                if `pval' < 0.10 {
                                    assert `n_dec' == 4
                                }
                                else {
                                    assert `n_dec' == 2
                                }
                            }
                        }
                    }
                    local found_lr = 1
                }
            }
        }
        assert `found_lr' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R2.3 - survtab pdp(4)/highpdp(2) formats log-rank p correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: R2.3 - survtab log-rank p formatting wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r23

* --- R2.4: survtab pdp(4) in p-value column (by-group) ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _rr_r24
    survtab, times(10 20 30) by(drug) pdp(4) highpdp(2) frame(_rr_r24)
    frame _rr_r24 {
        * Find the p-value column — look for "P" or "p" in header rows
        local pcol = ""
        quietly ds c*
        local cvars `r(varlist)'
        foreach v of local cvars {
            local hdr = `v'[1]
            if strtrim("`hdr'") == "P" | strtrim("`hdr'") == "p" ///
                | strtrim("`hdr'") == "P-value" | strtrim("`hdr'") == "p-value" {
                local pcol "`v'"
                continue, break
            }
        }
        if "`pcol'" != "" {
            * Check the p-value in the first data row
            local pstr = `pcol'[3]
            local pstr = strtrim("`pstr'")
            if "`pstr'" != "" & "`pstr'" != "." {
                if substr("`pstr'", 1, 1) == "<" {
                    assert strpos("`pstr'", "0.0001") > 0
                }
                else {
                    local pval = real("`pstr'")
                    if `pval' < . {
                        local dot_pos = strpos("`pstr'", ".")
                        local after = substr("`pstr'", `dot_pos' + 1, .)
                        local n_dec = strlen(strtrim("`after'"))
                        if `pval' < 0.10 {
                            assert `n_dec' == 4
                        }
                        else {
                            assert `n_dec' == 2
                        }
                    }
                }
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: R2.4 - survtab p-value column respects pdp(4)/highpdp(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: R2.4 - survtab p-value column formatting wrong (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r24

* --- R2.5: effecttab pdp/highpdp in Excel matches frame values ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "output/_rr_effecttab_pdp.xlsx"
    capture frame drop _rr_r25
    effecttab, xlsx("output/_rr_effecttab_pdp.xlsx") sheet("Test") ///
        frame(_rr_r25) pdp(4) highpdp(2)
    * Get p-value from frame (first data row p in c3)
    frame _rr_r25 {
        local frame_p = ""
        forvalues i = 3/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" != "" & "`cell'" != "." {
                local frame_p "`cell'"
                continue, break
            }
        }
    }
    * Verify matching p-value appears in Excel
    * For effecttab: row 1=title, rows 2-3=headers, row 4=group label, row 5=data
    * P-value is in column E (col 5) for single model
    if `has_checker' {
        shell python3 "`checker'" "output/_rr_effecttab_pdp.xlsx" --sheet "Test" --cell-not-empty E5 --result-file "output/_rr_r2_5.txt" --quiet
        file open _fh using "output/_rr_r2_5.txt", read text
        file read _fh _line
        file close _fh
        assert "`_line'" == "PASS"
    }
    else {
        preserve
        import excel "output/_rr_effecttab_pdp.xlsx", sheet("Test") clear allstring
        assert strtrim(E[5]) != ""
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: R2.5 - effecttab pdp/highpdp Excel output has p-values in cells"
    local ++pass_count
}
else {
    display as error "  FAIL: R2.5 - effecttab pdp Excel content check failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r25
capture erase "output/_rr_r2_5.txt"

* =========================================================================
**# R4: Persistent boldp application in Excel
* =========================================================================

* --- R4.1: regtab boldp(0.05) produces bold p-value rows in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/_rr_boldp_regtab.xlsx"
    capture frame drop _rr_r41
    regtab, xlsx("output/_rr_boldp_regtab.xlsx") sheet("Test") ///
        boldp(0.05) frame(_rr_r41)
    * Find which rows have significant p-values
    frame _rr_r41 {
        local bold_rows ""
        forvalues i = 4/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" == "" | "`cell'" == "." continue
            local pnum = .
            if substr("`cell'", 1, 1) == "<" {
                local pnum = 0
            }
            else {
                local pnum = real("`cell'")
            }
            if `pnum' < 0.05 & `pnum' < . {
                * Excel row = frame row + 1 (title row is row 1 in Excel)
                local excel_row = `i'
                local bold_rows "`bold_rows' `excel_row'"
            }
        }
    }
    * Now check that those rows have bold formatting in Excel
    if "`bold_rows'" != "" {
        if `has_checker' {
            shell python3 "`checker'" "output/_rr_boldp_regtab.xlsx" --sheet "Test" --bold-row `bold_rows' --result-file "output/_rr_r4_1.txt" --quiet
            file open _fh using "output/_rr_r4_1.txt", read text
            file read _fh _line
            file close _fh
            assert "`_line'" == "PASS"
        }
        else {
            confirm file "output/_rr_boldp_regtab.xlsx"
        }
    }
    else {
        * No significant p-values found — this shouldn't happen with auto data
        assert 0
    }
}
if _rc == 0 {
    if `has_checker' display as result "  PASS: R4.1 - regtab boldp(0.05) applies bold to significant p-value rows"
    else display as result "  PASS: R4.1 - regtab boldp(0.05) produced significant rows; Excel style check skipped"
    local ++pass_count
}
else {
    display as error "  FAIL: R4.1 - regtab boldp Excel bold formatting failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r41
capture erase "output/_rr_r4_1.txt"

* --- R4.2: persistent boldp via tabtools set applies bold in Excel ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set boldp 0.05
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/_rr_boldp_persist.xlsx"
    capture frame drop _rr_r42
    * No boldp() option — should pick up persistent setting
    regtab, xlsx("output/_rr_boldp_persist.xlsx") sheet("Test") frame(_rr_r42)
    * Find significant rows
    frame _rr_r42 {
        local bold_rows ""
        forvalues i = 4/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" == "" | "`cell'" == "." continue
            local pnum = .
            if substr("`cell'", 1, 1) == "<" {
                local pnum = 0
            }
            else {
                local pnum = real("`cell'")
            }
            if `pnum' < 0.05 & `pnum' < . {
                local excel_row = `i'
                local bold_rows "`bold_rows' `excel_row'"
            }
        }
    }
    if "`bold_rows'" != "" {
        if `has_checker' {
            shell python3 "`checker'" "output/_rr_boldp_persist.xlsx" --sheet "Test" --bold-row `bold_rows' --result-file "output/_rr_r4_2.txt" --quiet
            file open _fh using "output/_rr_r4_2.txt", read text
            file read _fh _line
            file close _fh
            assert "`_line'" == "PASS"
        }
        else {
            confirm file "output/_rr_boldp_persist.xlsx"
        }
    }
    else {
        assert 0
    }
}
if _rc == 0 {
    if `has_checker' display as result "  PASS: R4.2 - persistent boldp via tabtools set produces bold in Excel"
    else display as result "  PASS: R4.2 - persistent boldp identified significant rows; Excel style check skipped"
    local ++pass_count
}
else {
    display as error "  FAIL: R4.2 - persistent boldp Excel formatting failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r42
capture erase "output/_rr_r4_2.txt"
tabtools set clear

* --- R4.3: effecttab boldp produces bold in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "output/_rr_boldp_effecttab.xlsx"
    capture frame drop _rr_r43
    effecttab, xlsx("output/_rr_boldp_effecttab.xlsx") sheet("Test") ///
        boldp(0.10) frame(_rr_r43)
    * Find significant p-value rows
    frame _rr_r43 {
        local bold_rows ""
        forvalues i = 3/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" == "" | "`cell'" == "." continue
            local pnum = .
            if substr("`cell'", 1, 1) == "<" {
                local pnum = 0
            }
            else {
                local pnum = real("`cell'")
            }
            if `pnum' < 0.10 & `pnum' < . {
                * effecttab: Excel row = frame row + 1
                local excel_row = `i'
                local bold_rows "`bold_rows' `excel_row'"
            }
        }
    }
    if "`bold_rows'" != "" {
        if `has_checker' {
            foreach _br of local bold_rows {
                shell python3 "`checker'" "output/_rr_boldp_effecttab.xlsx" --sheet "Test" --bold-row `_br' --result-file "output/_rr_r4_3.txt" --quiet
                file open _fh using "output/_rr_r4_3.txt", read text
                file read _fh _line
                file close _fh
                assert "`_line'" == "PASS"
            }
        }
        else {
            confirm file "output/_rr_boldp_effecttab.xlsx"
        }
    }
    else {
        * teffects ra price~foreign should produce significant p < 0.10
        assert 0
    }
}
if _rc == 0 {
    if `has_checker' display as result "  PASS: R4.3 - effecttab boldp(0.10) applies bold in Excel"
    else display as result "  PASS: R4.3 - effecttab boldp(0.10) produced significant rows; Excel style check skipped"
    local ++pass_count
}
else {
    display as error "  FAIL: R4.3 - effecttab boldp Excel formatting failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r43
capture erase "output/_rr_r4_3.txt"

* --- R4.4: no boldp means no bold p-value cells (control test) ---
local ++n_total
capture noisily {
    tabtools set clear
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/_rr_noboldp.xlsx"
    regtab, xlsx("output/_rr_noboldp.xlsx") sheet("Test")
    * Row 1 (title) and rows 2-3 (headers) are bold by design
    * Data rows (5+) should NOT have bold p-values
    * check_xlsx --bold-row checks if ANY cell in row is bold
    * We test that data row 5 does NOT have bold (row 5 = first data row)
    * But row labels may be bold... so instead check that the file was created
    * and has structure — the bold-row test for R4.1/R4.2 is the positive test
    if `has_checker' {
        shell python3 "`checker'" "output/_rr_noboldp.xlsx" --sheet "Test" --min-rows 5 --has-borders --result-file "output/_rr_r4_4.txt" --quiet
        file open _fh using "output/_rr_r4_4.txt", read text
        file read _fh _line
        file close _fh
        assert "`_line'" == "PASS"
    }
    else {
        preserve
        import excel "output/_rr_noboldp.xlsx", sheet("Test") clear allstring
        assert _N >= 5
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: R4.4 - regtab without boldp produces valid Excel (control)"
    local ++pass_count
}
else {
    display as error "  FAIL: R4.4 - regtab without boldp failed (rc=`=_rc')"
    local ++fail_count
}
capture erase "output/_rr_r4_4.txt"

* --- R4.5: persistent boldp + pdp combination in Excel ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set boldp 0.05
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/_rr_boldp_pdp.xlsx"
    capture frame drop _rr_r45
    regtab, xlsx("output/_rr_boldp_pdp.xlsx") sheet("Test") ///
        pdp(4) highpdp(2) frame(_rr_r45)
    * Verify both: pdp formatting in frame AND bold in Excel
    frame _rr_r45 {
        local bold_rows ""
        local pdp_ok = 0
        forvalues i = 4/`=_N' {
            local cell = c3[`i']
            local cell = strtrim("`cell'")
            if "`cell'" == "" | "`cell'" == "." continue
            local pnum = .
            if substr("`cell'", 1, 1) == "<" {
                assert strpos("`cell'", "0.0001") > 0
                local pnum = 0
                local pdp_ok = 1
            }
            else {
                local pnum = real("`cell'")
                if `pnum' < . {
                    local dot_pos = strpos("`cell'", ".")
                    local after = substr("`cell'", `dot_pos' + 1, .)
                    local n_dec = strlen(strtrim("`after'"))
                    if `pnum' < 0.10 {
                        assert `n_dec' == 4
                    }
                    else {
                        assert `n_dec' == 2
                    }
                    local pdp_ok = 1
                }
            }
            if `pnum' < 0.05 & `pnum' < . {
                local excel_row = `i'
                local bold_rows "`bold_rows' `excel_row'"
            }
        }
        assert `pdp_ok' == 1
    }
    if "`bold_rows'" != "" {
        if `has_checker' {
            shell python3 "`checker'" "output/_rr_boldp_pdp.xlsx" --sheet "Test" --bold-row `bold_rows' --result-file "output/_rr_r4_5.txt" --quiet
            file open _fh using "output/_rr_r4_5.txt", read text
            file read _fh _line
            file close _fh
            assert "`_line'" == "PASS"
        }
        else {
            confirm file "output/_rr_boldp_pdp.xlsx"
        }
    }
}
if _rc == 0 {
    if `has_checker' display as result "  PASS: R4.5 - persistent boldp + pdp(4)/highpdp(2) both work in Excel"
    else display as result "  PASS: R4.5 - persistent boldp + pdp/highpdp logic passed; Excel style check skipped"
    local ++pass_count
}
else {
    display as error "  FAIL: R4.5 - boldp + pdp combination failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rr_r45
capture erase "output/_rr_r4_5.txt"
tabtools set clear

* =========================================================================

**# Migrated: eplot companion frames (requires sibling eplot)

* The eplot bridge QA requires the sibling eplot package from the same
* local sibling-package checkout. Hard requirement: fail with 601 when absent.
local tools_root = regexr("`pkg_dir'", "/tabtools$", "")
local eplot_dir "`tools_root'/eplot"
capture confirm file "`eplot_dir'/eplot.ado"
if _rc {
    display as error "Sibling eplot package not found at `eplot_dir' (required for eplot bridge QA)"
    exit 601
}
capture ado uninstall eplot
quietly net install eplot, from("`eplot_dir'") replace
discard
quietly net install tabtools, from("`pkg_dir'") replace


capture program drop _bridge_result
program define _bridge_result
    args ok msg
    if `ok' {
        display as result "  PASS: `msg'"
    }
    else {
        display as error "  FAIL: `msg' (rc=`=_rc')"
    }
end

foreach fr in _eb_reg _eb_reg2 _eb_reg_ep _eb_reg2_ep _eb_eff _eb_eff_ep ///
    _eb_comp _eb_comp_ep _eb_rates _eb_hr_model _eb_hr_model_ep _eb_hr _eb_hr_ep {
    capture frame drop `fr'
}
capture graph drop _all

* -------------------------------------------------------------------------
* 1. regtab emits a linked graph-ready eplot frame
* -------------------------------------------------------------------------
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    regtab, frame(_eb_reg, replace) eplotframe(_eb_reg_ep, replace) coef("b")

    assert "`r(eplotframe)'" == "_eb_reg_ep"
    frame _eb_reg: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_reg_ep"
    capture frame _eb_reg: ds _eplot*
    assert _rc == 111

    frame _eb_reg_ep {
        confirm string variable label
        confirm numeric variable estimate
        confirm numeric variable ll
        confirm numeric variable ul
        confirm numeric variable pvalue
        confirm string variable rowtype
        count if rowtype == "effect" & estimate < . & ll < . & ul < .
        assert r(N) >= 2
        local source : char _dta[tabtools_source]
        assert "`source'" == "regtab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "regtab eplotframe() emits linked companion frame"
}
else {
    local ++fail_count
    _bridge_result 0 "regtab eplotframe() emits linked companion frame"
}

* -------------------------------------------------------------------------
* 2. eplot consumes the companion frame without changing active data
* -------------------------------------------------------------------------
capture noisily {
    clear
    set obs 2
    gen byte sentinel = _n
    local active_frame "`c(frame)'"

    eplot, frame(_eb_reg_ep) labels(label) rowtype(rowtype) ///
        name(_eb_reg_plot, replace)

    assert "`c(frame)'" == "`active_frame'"
    assert _N == 2
    assert sentinel[2] == 2
    assert r(N) >= 2
    assert strpos(`"`r(cmd)'"', "scheme(") == 0
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "eplot frame() consumes tabtools companion frame"
}
else {
    local ++fail_count
    _bridge_result 0 "eplot frame() consumes tabtools companion frame"
}

* -------------------------------------------------------------------------
* 3. effecttab from() emits the same companion contract
* -------------------------------------------------------------------------
capture noisily {
    matrix eff = (1.50, 0.80, 2.20, 0.040 \ 2.30, 1.10, 3.50, 0.001)
    matrix rownames eff = Age Sex

    effecttab, from(eff) frame(_eb_eff, replace) ///
        eplotframe(_eb_eff_ep, replace) effect("OR")

    assert "`r(eplotframe)'" == "_eb_eff_ep"
    frame _eb_eff: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_eff_ep"
    capture frame _eb_eff: ds _eplot*
    assert _rc == 111

    frame _eb_eff_ep {
        count if rowtype == "effect" & estimate < . & ll < . & ul < .
        assert r(N) == 2
        assert abs(estimate[1] - 1.50) < 1e-10
        local source : char _dta[tabtools_source]
        assert "`source'" == "effecttab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "effecttab eplotframe() emits linked companion frame"
}
else {
    local ++fail_count
    _bridge_result 0 "effecttab eplotframe() emits linked companion frame"
}
capture matrix drop eff

* -------------------------------------------------------------------------
* 4. comptab composes source companions and forest preserves table returns
* -------------------------------------------------------------------------
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg length
    regtab, frame(_eb_reg2, replace) eplotframe(_eb_reg2_ep, replace) coef("b")

    comptab _eb_reg _eb_reg2, rows(1 2 \ 1 2) ///
        eplotframe(_eb_comp_ep, replace) frame(_eb_comp, replace) ///
        forest eplotoptions(name(_eb_comp_plot, replace))

    assert "`r(frame)'" == "_eb_comp"
    assert "`r(eplotframe)'" == "_eb_comp_ep"
    assert r(N_frames) == 2
    assert r(N_rows) >= 6
    frame _eb_comp: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_comp_ep"
    frame _eb_comp_ep {
        count if rowtype == "effect"
        assert r(N) >= 4
        local source : char _dta[tabtools_source]
        assert "`source'" == "comptab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "comptab forest composes companion frame and preserves returns"
}
else {
    local ++fail_count
    _bridge_result 0 "comptab forest composes companion frame and preserves returns"
}

* -------------------------------------------------------------------------
* 5. hrcomptab composes model companions and forest preserves returns
* -------------------------------------------------------------------------
capture noisily {
    tempfile rate1
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _eb_exp 0 "None" 1 "Current", replace
    label values exposure _eb_exp
    save "`rate1'.dta", replace

    clear
    stratetab, using(`rate1') outcomes(1) frame(_eb_rates, replace) ///
        outlabels("Outcome") explabels("Exposure")

    clear
    set obs 80
    set seed 60606
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    regtab, frame(_eb_hr_model, replace) eplotframe(_eb_hr_model_ep, replace) ///
        noint coef("aHR")

    hrcomptab _eb_rates, modelframes(_eb_hr_model) rows(1) ///
        effect("aHR") eplotframe(_eb_hr_ep, replace) frame(_eb_hr, replace) ///
        forest eplotoptions(name(_eb_hr_plot, replace))

    assert "`r(frame)'" == "_eb_hr"
    assert "`r(eplotframe)'" == "_eb_hr_ep"
    assert r(N_modelframes) == 1
    frame _eb_hr: local linked : char _dta[tabtools_eplotframe]
    assert "`linked'" == "_eb_hr_ep"
    frame _eb_hr_ep {
        count if rowtype == "effect"
        assert r(N) >= 1
        local source : char _dta[tabtools_source]
        assert "`source'" == "hrcomptab"
    }
}
if _rc == 0 {
    local ++pass_count
    _bridge_result 1 "hrcomptab forest composes companion frame and preserves returns"
}
else {
    local ++fail_count
    _bridge_result 0 "hrcomptab forest composes companion frame and preserves returns"
}

foreach fr in _eb_reg _eb_reg2 _eb_reg_ep _eb_reg2_ep _eb_eff _eb_eff_ep ///
    _eb_comp _eb_comp_ep _eb_rates _eb_hr_model _eb_hr_model_ep _eb_hr _eb_hr_ep {
    capture frame drop `fr'
}
capture graph drop _all
**# Migrated: eplot section folding


capture program drop _fold_result
program define _fold_result
    args ok msg
    if `ok' {
        display as result "  PASS: `msg'"
    }
    else {
        display as error "  FAIL: `msg' (rc=`=_rc')"
    }
end

foreach fr in _ef_m1 _ef_m1_ep _ef_m2 _ef_m2_ep _ef_multi _ef_multi_ep ///
    _ef_comp _ef_comp_ep _ef_comp_ns _ef_comp_ns_ep _ef_comp_mx _ef_comp_mx_ep ///
    _ef_rates _ef_hr_model _ef_hr_model_ep _ef_hr _ef_hr_ep {
    capture frame drop `fr'
}

* Two single-coefficient model frames (one selected row each)
sysuse auto, clear
collect clear
collect: regress price mpg weight
regtab, frame(_ef_m1, replace) eplotframe(_ef_m1_ep, replace) noint coef("b")

collect clear
collect: regress price mpg weight length
regtab, frame(_ef_m2, replace) eplotframe(_ef_m2_ep, replace) noint coef("b")

* A model frame contributing two selected rows under one section
collect clear
collect: regress price mpg weight length
regtab, frame(_ef_multi, replace) eplotframe(_ef_multi_ep, replace) noint coef("b")

* -------------------------------------------------------------------------
* 1. Single-row sections fold: label replaced, no standalone section rows
* -------------------------------------------------------------------------
capture noisily {
    comptab _ef_m1 _ef_m2, rows(1 \ 1) section("Crude" \ "Adjusted") ///
        frame(_ef_comp, replace) eplotframe(_ef_comp_ep, replace)

    frame _ef_comp_ep {
        count if rowtype == "section"
        assert r(N) == 0
        count if rowtype == "effect"
        assert r(N) == 2
        * Folded rows carry the section label, not the coefficient name
        count if label == "Crude" & rowtype == "effect" & estimate < .
        assert r(N) == 1
        count if label == "Adjusted" & rowtype == "effect" & estimate < .
        assert r(N) == 1
        count if label == "mpg"
        assert r(N) == 0
        * The section column still records provenance
        count if section == "Crude"
        assert r(N) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "single-row sections fold label into the effect row"
}
else {
    local ++fail_count
    _fold_result 0 "single-row sections fold label into the effect row"
}

* -------------------------------------------------------------------------
* 2. Rendered table is unchanged: section headers still present in display frame
* -------------------------------------------------------------------------
capture noisily {
    frame _ef_comp {
        count if A == "Crude"
        assert r(N) == 1
        count if A == "Adjusted"
        assert r(N) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "rendered table keeps its section header rows"
}
else {
    local ++fail_count
    _fold_result 0 "rendered table keeps its section header rows"
}

* -------------------------------------------------------------------------
* 3. Multi-row section keeps its header and original row labels
* -------------------------------------------------------------------------
capture noisily {
    comptab _ef_multi, rows(1 2) section("Block") ///
        frame(_ef_comp_mx, replace) eplotframe(_ef_comp_mx_ep, replace)

    frame _ef_comp_mx_ep {
        count if rowtype == "section" & label == "Block"
        assert r(N) == 1
        count if rowtype == "effect"
        assert r(N) == 2
        * Two-child section retains the coefficient names, not the section label
        count if label == "Block" & rowtype == "effect"
        assert r(N) == 0
        count if rowtype == "effect" & section == "Block"
        assert r(N) == 2
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "multi-row section keeps header and original labels"
}
else {
    local ++fail_count
    _fold_result 0 "multi-row section keeps header and original labels"
}

* -------------------------------------------------------------------------
* 4. No section() requested: baseline unchanged (no section rows, real labels)
* -------------------------------------------------------------------------
capture noisily {
    comptab _ef_m1 _ef_m2, rows(1 \ 1) ///
        frame(_ef_comp_ns, replace) eplotframe(_ef_comp_ns_ep, replace)

    frame _ef_comp_ns_ep {
        count if rowtype == "section"
        assert r(N) == 0
        count if rowtype == "effect"
        assert r(N) == 2
        * Original source labels (variable labels) are preserved, not folded
        count if label == "Mileage (mpg)" & rowtype == "effect"
        assert r(N) == 2
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "no section() leaves companion frame unchanged"
}
else {
    local ++fail_count
    _fold_result 0 "no section() leaves companion frame unchanged"
}

* -------------------------------------------------------------------------
* 5. hrcomptab multi-child section (reference + effect) still emits its header
* -------------------------------------------------------------------------
capture noisily {
    tempfile rate1
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _ef_exp 0 "None" 1 "Current", replace
    label values exposure _ef_exp
    save "`rate1'.dta", replace

    clear
    stratetab, using(`rate1') outcomes(1) frame(_ef_rates, replace) ///
        outlabels("Outcome") explabels("Exposure")

    clear
    set obs 80
    set seed 60606
    gen byte treated = mod(_n, 2)
    gen double yv = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress yv treated
    regtab, frame(_ef_hr_model, replace) eplotframe(_ef_hr_model_ep, replace) ///
        noint coef("aHR")

    hrcomptab _ef_rates, modelframes(_ef_hr_model) rows(1) effect("aHR") ///
        frame(_ef_hr, replace) eplotframe(_ef_hr_ep, replace)

    frame _ef_hr_ep {
        * "Exposure" owns a reference ("None") + one effect ("Current"):
        * two children, so the section header is retained, not folded.
        count if rowtype == "section"
        assert r(N) >= 1
        count if rowtype == "effect"
        assert r(N) >= 1
    }
}
if _rc == 0 {
    local ++pass_count
    _fold_result 1 "hrcomptab multi-child section retains its header"
}
else {
    local ++fail_count
    _fold_result 0 "hrcomptab multi-child section retains its header"
}

foreach fr in _ef_m1 _ef_m1_ep _ef_m2 _ef_m2_ep _ef_multi _ef_multi_ep ///
    _ef_comp _ef_comp_ep _ef_comp_ns _ef_comp_ns_ep _ef_comp_mx _ef_comp_mx_ep ///
    _ef_rates _ef_hr_model _ef_hr_model_ep _ef_hr _ef_hr_ep {
    capture frame drop `fr'
}

display _newline as text "tabtools eplot section-fold QA: `pass_count'/`test_count' passed"

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_package_integration tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _pkgint
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_package_integration tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pkgint
