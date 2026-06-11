* test_regression_fixes.do — Regression tests for tabtools bug fixes
* Date: 2026-04-03
* Covers: corrtab pairwise N, custom theme colors, stratetab sheet
*         validation, zebra in crosstab, tabtools detail listing

clear all
set varabbrev off

capture log close _regfix
log using "test_regression_fixes.log", replace text name(_regfix)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0


**# 1. corrtab pairwise N — p-values must use pairwise N, not listwise

**## 1a. Pearson: pairwise N matches direct computation
local ++test_count
local t1a_pass = 1
capture noisily {
    clear
    set seed 12345
    set obs 100
    gen x = rnormal()
    gen y = rnormal() + 0.3*x
    gen z = rnormal() + 0.2*x
    replace y = . if _n > 80
    replace z = . if _n > 40

    corrtab x y z, pvalues xlsx("`output_dir'/_regfix_corrtab_pw.xlsx") sheet("pw")

    * Check pairwise N matrix
    assert r(N)[1,1] == 100
    assert r(N)[1,2] == 80
    assert r(N)[1,3] == 40
}
if _rc != 0 {
    display as error "  FAIL [1a.run]: corrtab pairwise N returned error `=_rc'"
    local t1a_pass = 0
}
else {
    * Verify p-values match direct pairwise computation
    tempname pmat nmat
    matrix `pmat' = r(P)
    matrix `nmat' = r(N)

    * x-y pair: N should be 80
    if `nmat'[1,2] == 80 {
        display as result "  PASS [1a.N_xy]: pairwise N(x,y) = 80"
    }
    else {
        display as error "  FAIL [1a.N_xy]: expected N(x,y) = 80, got `=`nmat'[1,2]'"
        local t1a_pass = 0
    }

    * x-z pair: N should be 40
    if `nmat'[1,3] == 40 {
        display as result "  PASS [1a.N_xz]: pairwise N(x,z) = 40"
    }
    else {
        display as error "  FAIL [1a.N_xz]: expected N(x,z) = 40, got `=`nmat'[1,3]'"
        local t1a_pass = 0
    }

    * Verify p-value for x-y against direct calculation
    clear
    set seed 12345
    set obs 100
    gen x = rnormal()
    gen y = rnormal() + 0.3*x
    replace y = . if _n > 80

    qui correlate x y
    local direct_r = r(rho)
    local direct_n = r(N)
    local direct_t = `direct_r' * sqrt((`direct_n' - 2) / (1 - `direct_r'^2))
    local direct_p = 2 * ttail(`direct_n' - 2, abs(`direct_t'))

    local corrtab_p = `pmat'[1,2]
    local p_diff = abs(`corrtab_p' - `direct_p')
    if `p_diff' < 0.0001 {
        display as result "  PASS [1a.p_xy]: p(x,y) matches direct (diff=`p_diff')"
    }
    else {
        display as error "  FAIL [1a.p_xy]: p(x,y) mismatch: corrtab=`corrtab_p' direct=`direct_p' diff=`p_diff'"
        local t1a_pass = 0
    }
}
if `t1a_pass' == 1 {
    display as result "  PASS: corrtab Pearson pairwise N"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Pearson pairwise N"
    local ++fail_count
}

**## 1b. Spearman: pairwise N matches direct computation
local ++test_count
local t1b_pass = 1
capture noisily {
    clear
    set seed 54321
    set obs 100
    gen x = rnormal()
    gen y = rnormal() + 0.4*x
    gen z = rnormal() + 0.3*x
    replace y = . if _n > 60
    replace z = . if _n > 30

    corrtab x y z, spearman pvalues xlsx("`output_dir'/_regfix_corrtab_sp.xlsx") sheet("sp")

    * Pairwise N
    assert r(N)[1,2] == 60
    assert r(N)[1,3] == 30
}
if _rc != 0 {
    display as error "  FAIL [1b.run]: corrtab Spearman pairwise N error `=_rc'"
    local t1b_pass = 0
}
else {
    tempname nmat_sp
    matrix `nmat_sp' = r(N)
    if `nmat_sp'[1,2] == 60 & `nmat_sp'[1,3] == 30 {
        display as result "  PASS [1b.N]: Spearman pairwise N correct (60, 30)"
    }
    else {
        display as error "  FAIL [1b.N]: Spearman pairwise N wrong"
        local t1b_pass = 0
    }
}
if `t1b_pass' == 1 {
    display as result "  PASS: corrtab Spearman pairwise N"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise N"
    local ++fail_count
}

**## 1c. No missingness: pairwise N equals total N for all pairs
local ++test_count
capture noisily {
    clear
    set seed 99999
    set obs 50
    gen x = rnormal()
    gen y = rnormal()
    gen z = rnormal()

    corrtab x y z, pvalues xlsx("`output_dir'/_regfix_corrtab_complete.xlsx") sheet("complete")

    assert r(N)[1,1] == 50
    assert r(N)[1,2] == 50
    assert r(N)[1,3] == 50
    assert r(N)[2,3] == 50
}
if _rc == 0 {
    display as result "  PASS: corrtab complete data — all pairwise N = 50"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab complete data pairwise N (error `=_rc')"
    local ++fail_count
}


**# 2. Custom theme colors — commands must respect global color settings

**## 2a. Commands resolve custom headercolor/zebracolor globals
local ++test_count
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
local ++test_count
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
local ++test_count
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
local ++test_count
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


**# 3. stratetab sheet() validation — must use sheet validator, not path validator

**## 3a. Invalid sheet name with / rejected early (r(198))
local ++test_count
capture noisily {
    * We need strate output data for stratetab — create minimal fake
    clear
    set obs 4
    gen _D = _n
    gen _Y = _n * 100
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.5
    gen _Upper = _Rate * 1.5
    gen group = mod(_n, 2) + 1

    save "`output_dir'/_regfix_strate_data.dta", replace

    stratetab, using("`output_dir'/_regfix_strate_data") outcomes(1) ///
        xlsx("`output_dir'/_regfix_stratetab_badsheet.xlsx") sheet("bad/name")
}
if _rc == 198 {
    display as result "  PASS: stratetab sheet('bad/name') rejected with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab sheet('bad/name') expected r(198), got `=_rc'"
    local ++fail_count
}

**## 3b. Invalid sheet name with * rejected early (r(198))
local ++test_count
capture noisily {
    clear
    set obs 4
    gen _D = _n
    gen _Y = _n * 100
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.5
    gen _Upper = _Rate * 1.5
    gen group = mod(_n, 2) + 1
    save "`output_dir'/_regfix_strate_data2.dta", replace

    stratetab, using("`output_dir'/_regfix_strate_data2") outcomes(1) ///
        xlsx("`output_dir'/_regfix_stratetab_star.xlsx") sheet("bad*name")
}
if _rc == 198 {
    display as result "  PASS: stratetab sheet('bad*name') rejected with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab sheet('bad*name') expected r(198), got `=_rc'"
    local ++fail_count
}

**## 3c. Sheet name over 31 chars rejected early (r(198))
local ++test_count
capture noisily {
    clear
    set obs 4
    gen _D = _n
    gen _Y = _n * 100
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.5
    gen _Upper = _Rate * 1.5
    gen group = mod(_n, 2) + 1
    save "`output_dir'/_regfix_strate_data3.dta", replace

    stratetab, using("`output_dir'/_regfix_strate_data3") outcomes(1) ///
        xlsx("`output_dir'/_regfix_stratetab_long.xlsx") ///
        sheet("This sheet name is way too long for Excel to handle")
}
if _rc == 198 {
    display as result "  PASS: stratetab 31+ char sheet name rejected with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab long sheet name expected r(198), got `=_rc'"
    local ++fail_count
}


**# 4. Zebra formatting in crosstab

**## 4a. crosstab zebra produces fills in xlsx
local ++test_count
local t4a_pass = 1
capture noisily {
    sysuse auto, clear
    crosstab foreign rep78, xlsx("`output_dir'/_regfix_crosstab_zebra.xlsx") sheet("cross") zebra
}
if _rc != 0 {
    display as error "  FAIL [4a.run]: crosstab zebra error `=_rc'"
    local t4a_pass = 0
}
else {
    capture noisily {
        ! cd "`output_dir'" && unzip -o _regfix_crosstab_zebra.xlsx xl/styles.xml -d _regfix_cross_inspect > /dev/null 2>&1
        ! grep -c 'EDF2F9\|edf2f9' "`output_dir'/_regfix_cross_inspect/xl/styles.xml" > "`output_dir'/_regfix_cross_fill_count.txt" 2>&1

        file open _fh using "`output_dir'/_regfix_cross_fill_count.txt", read text
        file read _fh _line
        file close _fh

        local fill_count = real(strtrim("`_line'"))
        assert `fill_count' > 0
    }
    if _rc == 0 {
        display as result "  PASS [4a.fill]: crosstab zebra fill present in xlsx"
    }
    else {
        display as error "  FAIL [4a.fill]: crosstab zebra fill NOT found in xlsx"
        local t4a_pass = 0
    }
}
if `t4a_pass' == 1 {
    display as result "  PASS: crosstab zebra produces fills"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab zebra produces fills"
    local ++fail_count
}


**# 5. tabtools detail listing — all commands and categories

**## 5a. tabtools returns 16 current commands
local ++test_count
capture noisily {
    tabtools
    assert r(n_commands) == 16
}
if _rc == 0 {
    display as result "  PASS: tabtools returns n_commands = 16"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools n_commands != 16 (error `=_rc')"
    local ++fail_count
}

**## 5b. All 9 categories are returned
local ++test_count
capture noisily {
    tabtools
    local cats = r(categories)
    assert strpos("`cats'", "descriptive") > 0
    assert strpos("`cats'", "models") > 0
    assert strpos("`cats'", "rates") > 0
    assert strpos("`cats'", "survival") > 0
    assert strpos("`cats'", "diagnostics") > 0
    assert strpos("`cats'", "composite") > 0
    assert strpos("`cats'", "export") > 0
    assert strpos("`cats'", "simulation") > 0
    assert strpos("`cats'", "general") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools returns all 9 categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools missing categories (error `=_rc')"
    local ++fail_count
}

**## 5c. Each category filter returns commands
local ++test_count
local t5c_pass = 1
foreach cat in descriptive models rates survival diagnostics composite export simulation general {
    capture noisily {
        tabtools, category(`cat')
        assert r(n_commands) > 0
    }
    if _rc == 0 {
        display as result "  PASS [5c.`cat']: category(`cat') returns commands"
    }
    else {
        display as error "  FAIL [5c.`cat']: category(`cat') failed (error `=_rc')"
        local t5c_pass = 0
    }
}
if `t5c_pass' == 1 {
    display as result "  PASS: all category filters return commands"
    local ++pass_count
}
else {
    display as error "  FAIL: some category filters failed"
    local ++fail_count
}

**## 5d. detail option works for all categories
local ++test_count
local t5d_pass = 1
foreach cat in all descriptive models rates survival diagnostics composite export simulation general {
    capture noisily {
        tabtools, detail category(`cat')
    }
    if _rc != 0 {
        display as error "  FAIL [5d.`cat']: tabtools, detail category(`cat') error `=_rc'"
        local t5d_pass = 0
    }
}
if `t5d_pass' == 1 {
    display as result "  PASS: tabtools detail works for all categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools detail failed for some categories"
    local ++fail_count
}

**## 5e. r(commands) contains all 16 current command names
local ++test_count
local t5e_pass = 1
capture noisily {
    tabtools
    local cmds = r(commands)
}
if _rc != 0 {
    display as error "  FAIL [5e.run]: tabtools error `=_rc'"
    local t5e_pass = 0
}
else {
    foreach cmd in table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab diagtab comptab hrcomptab puttab stacktab simtab tabtools tabtools_tips {
        if strpos("`cmds'", "`cmd'") > 0 {
            display as result "  PASS [5e.`cmd']: `cmd' in r(commands)"
        }
        else {
            display as error "  FAIL [5e.`cmd']: `cmd' missing from r(commands)"
            local t5e_pass = 0
        }
    }
}
if `t5e_pass' == 1 {
    display as result "  PASS: all 16 current commands in r(commands)"
    local ++pass_count
}
else {
    display as error "  FAIL: some commands missing from r(commands)"
    local ++fail_count
}


* Cleanup
capture erase "`output_dir'/_regfix_corrtab_pw.xlsx"
capture erase "`output_dir'/_regfix_corrtab_sp.xlsx"
capture erase "`output_dir'/_regfix_corrtab_complete.xlsx"
capture erase "`output_dir'/_regfix_custom_table1.xlsx"
capture erase "`output_dir'/_regfix_custom_fill.txt"
capture erase "`output_dir'/_regfix_stratetab_badsheet.xlsx"
capture erase "`output_dir'/_regfix_stratetab_star.xlsx"
capture erase "`output_dir'/_regfix_stratetab_long.xlsx"
capture erase "`output_dir'/_regfix_strate_data.dta"
capture erase "`output_dir'/_regfix_strate_data2.dta"
capture erase "`output_dir'/_regfix_strate_data3.dta"
capture erase "`output_dir'/_regfix_crosstab_zebra.xlsx"
capture erase "`output_dir'/_regfix_cross_fill_count.txt"
capture {
    shell rm -rf "`output_dir'/_regfix_cross_inspect"
}

display _newline as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _regfix
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _regfix
