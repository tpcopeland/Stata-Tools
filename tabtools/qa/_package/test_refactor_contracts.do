* test_refactor_contracts.do - S0 behavior contracts for tabtools refactors
* Run from tabtools/qa or tabtools/qa/_package.

clear all
version 17.0
set more off
set varabbrev off

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local pkg_dir = regexr("`_cwd'", "/qa/_package$", "")
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_dir = regexr("`_cwd'", "/qa$", "")
    local qa_dir "`_cwd'"
}
else {
    local pkg_dir "`_cwd'"
    local qa_dir "`pkg_dir'/qa"
}

local output_dir "`qa_dir'/output"
local baseline_dir "`qa_dir'/baseline"
local summary_dir "`baseline_dir'/summaries"
local manifest_file "`baseline_dir'/baseline_manifest.tsv"
local summary_tool "`qa_dir'/tools/summarize_xlsx.py"
capture mkdir "`output_dir'"

capture log close _all
log using "`output_dir'/test_refactor_contracts.log", replace text name(_refactor_contracts)

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
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

program define _contract_make_rate
    version 17.0
    syntax , BASENAME(string)
    clear
    set obs 2
    gen byte exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2
    label define contract_exp 0 "None" 1 "Current", replace
    label values exposure contract_exp
    save "`basename'.dta", replace
end

**# Fresh Install And Helper Readiness
local ++test_count
capture noisily {
    capture ado uninstall tabtools
    quietly net install tabtools, from("`pkg_dir'") replace
    discard

    foreach cmd in tabtools table1_tc desctab regtab effecttab stratetab ///
        hrcomptab comptab survtab crosstab diagtab corrtab {
        which `cmd'
    }

    clear
    input byte row byte col
    0 0
    0 1
    1 0
    1 1
    end
    crosstab row col, display
    assert r(N) == 4

    findfile _tabtools_common.ado
    run "`r(fn)'"
    _tabtools_helpers_ready
}
if _rc == 0 {
    display as result "  PASS: fresh install resolves commands and helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: fresh install/helper readiness (rc=`=_rc')"
    local ++fail_count
}

**# Baseline Summary Contracts
local ++test_count
capture noisily {
    confirm file "`manifest_file'"

    preserve
    import delimited "`manifest_file'", varnames(1) stringcols(_all) clear
    assert _N >= 15
    forvalues i = 1/`=_N' {
        assert status[`i'] == "PASS"
        local sheet = sheet[`i']
        local summary = summary_file[`i']
        confirm file "`pkg_dir'/`summary'"
        tempname sfh
        file open `sfh' using "`pkg_dir'/`summary'", read text
        file read `sfh' header
        file read `sfh' row
        file close `sfh'
        assert strpos(`"`header'"', "content_digest") > 0
        assert strpos(`"`header'"', "nonempty_text_count") > 0
        assert substr(`"`row'"', 1, 4) == "PASS"
        assert strpos(`"`row'"', "`sheet'") > 0
        assert strpos(`"`row'"', "SKIP") == 0
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: all manifest baseline summaries are checked-in and content-sensitive"
    local ++pass_count
}
else {
    display as error "  FAIL: baseline summary contract drift (rc=`=_rc')"
    local ++fail_count
}

**# Public Command Return Contracts
local ++test_count
capture noisily {
    tabtools set clear
    tabtools
    assert r(n_commands) == 15
    assert strpos("`r(commands)'", "table1_tc") > 0
    assert strpos("`r(commands)'", "desctab") > 0
    assert strpos("`r(commands)'", "regtab") > 0

    local xlsx "`output_dir'/contract_table1.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_t1
    sysuse auto, clear
    table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto) ///
        xlsx("`xlsx'") sheet("Table1") frame(contract_t1, replace) ///
        title("Contract table1")
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Table1"
    assert "`r(frame)'" == "contract_t1"
    assert `"`r(methods)'"' != ""
    assert strpos("`r(varlist)'", "price") > 0
    matrix contract_t1_m = r(table)
    assert rowsof(contract_t1_m) > 0
    frame contract_t1: assert _N > 0

    local xlsx "`output_dir'/contract_crosstab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_cross
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    crosstab outcome exposure, or rr rd xlsx("`xlsx'") sheet("Cross") ///
        frame(contract_cross, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Cross"
    assert "`r(frame)'" == "contract_cross"
    assert r(N) == 100
    assert `"`r(methods)'"' != ""
    matrix contract_cross_m = r(table)
    assert rowsof(contract_cross_m) > 0

    local xlsx "`output_dir'/contract_corrtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_corr
    sysuse auto, clear
    corrtab price mpg weight, spearman lower pvalues ///
        xlsx("`xlsx'") sheet("Corr") frame(contract_corr, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Corr"
    assert "`r(frame)'" == "contract_corr"
    assert `"`r(methods)'"' != ""
    matrix contract_corr_c = r(C)
    matrix contract_corr_n = r(N)
    assert colsof(contract_corr_c) == 3
    assert contract_corr_n[1,1] > 0

    local xlsx "`output_dir'/contract_diagtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_diag
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0
    replace test = 1 in 1/40
    replace test = 1 in 51/70
    diagtab test gold, xlsx("`xlsx'") sheet("Diag") ///
        frame(contract_diag, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Diag"
    assert "`r(frame)'" == "contract_diag"
    assert `"`r(methods)'"' != ""
    assert abs(r(sensitivity) - 0.8) < 1e-10
    assert abs(r(specificity) - 0.6) < 1e-10

    local xlsx "`output_dir'/contract_survtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_surv
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(5 10 15 20) by(drug) xlsx("`xlsx'") ///
        sheet("Surv") frame(contract_surv, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Surv"
    assert "`r(frame)'" == "contract_surv"
    assert r(N_rows) > 0
    assert `"`r(methods)'"' != ""

    tempfile rate1 rate2
    _contract_make_rate, basename("`rate1'")
    _contract_make_rate, basename("`rate2'")
    local xlsx "`output_dir'/contract_stratetab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_rates
    clear
    stratetab, using("`rate1'" "`rate2'") outcomes(2) ///
        xlsx("`xlsx'") sheet("Rates") frame(contract_rates, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Rates"
    assert "`r(frame)'" == "contract_rates"
    assert r(N_rows) >= 6
    assert r(N_outcomes) == 2

    local xlsx "`output_dir'/contract_regtab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_reg
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`xlsx'") sheet("Reg") frame(contract_reg, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Reg"
    assert "`r(frame)'" == "contract_reg"
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert r(N_models) == 1
    assert `"`r(methods)'"' != ""
    matrix contract_reg_m = r(table)
    assert rowsof(contract_reg_m) > 0

    local xlsx "`output_dir'/contract_effecttab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_eff
    sysuse auto, clear
    quietly regress price mpg weight
    collect clear
    collect: margins, dydx(mpg weight)
    effecttab, type(margins) xlsx("`xlsx'") sheet("Effect") ///
        frame(contract_eff, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Effect"
    assert "`r(frame)'" == "contract_eff"
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert "`r(type)'" == "margins"
    assert `"`r(methods)'"' != ""
    matrix contract_eff_m = r(table)
    assert rowsof(contract_eff_m) > 0

    local xlsx "`output_dir'/contract_desctab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_desc
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price) statistic(mean price)
    desctab, xlsx("`xlsx'") sheet("Desc") frame(contract_desc, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Desc"
    assert "`r(frame)'" == "contract_desc"
    assert r(N_rows) > 0
    assert r(N_cells) > 0
    assert `"`r(methods)'"' != ""
    matrix contract_desc_m = r(table)
    assert rowsof(contract_desc_m) > 0

    capture frame drop contract_comp1
    capture frame drop contract_comp2
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    regtab, frame(contract_comp1, replace) noint
    collect clear
    collect: regress price foreign mpg weight length
    regtab, frame(contract_comp2, replace) noint
    local xlsx "`output_dir'/contract_comptab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_comp
    comptab contract_comp1 contract_comp2, rows(1 \ 1 2) ///
        xlsx("`xlsx'") sheet("Comp") frame(contract_comp, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Comp"
    assert "`r(frame)'" == "contract_comp"
    assert r(N_rows) == 6
    assert r(N_cols) == 5
    assert r(N_frames) == 2
    assert `"`r(methods)'"' != ""

    capture frame drop contract_hr_rates
    capture frame drop contract_hr_model
    tempfile hrate1 hrate2
    _contract_make_rate, basename("`hrate1'")
    _contract_make_rate, basename("`hrate2'")
    clear
    stratetab, using("`hrate1'" "`hrate2'") outcomes(2) ///
        frame(contract_hr_rates, replace)
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    collect: regress price foreign mpg weight length
    regtab, frame(contract_hr_model, replace) noint
    local xlsx "`output_dir'/contract_hrcomptab.xlsx"
    capture erase "`xlsx'"
    capture frame drop contract_hr
    hrcomptab contract_hr_rates, modelframes(contract_hr_model) rows(1) ///
        xlsx("`xlsx'") sheet("HR") frame(contract_hr, replace)
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "HR"
    assert "`r(frame)'" == "contract_hr"
    assert r(N_rows) > 0
    assert r(N_outcomes) == 2
    assert r(N_modelrows) == 1
}
if _rc == 0 {
    display as result "  PASS: public command return contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: public command return contracts (rc=`=_rc')"
    local ++fail_count
}
foreach fr in contract_t1 contract_cross contract_corr contract_diag contract_surv ///
    contract_rates contract_reg contract_eff contract_desc contract_comp1 ///
    contract_comp2 contract_comp contract_hr_rates contract_hr_model contract_hr {
    capture frame drop `fr'
}

**# Varabbrev Restoration Contracts
local ++test_count
capture noisily {
    sysuse auto, clear
    set varabbrev on
    table1_tc price mpg, by(foreign)
    assert "`c(varabbrev)'" == "on"

    clear
    input str1 row_s byte col
    "a" 0
    "b" 1
    "a" 0
    "b" 1
    end
    capture crosstab row_s col
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"

    collect clear
    capture desctab, display
    assert _rc == 119
    assert "`c(varabbrev)'" == "on"

    tempfile missing_rate
    capture stratetab, using("`missing_rate'") outcomes(1) display
    assert _rc == 601
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: representative success/error paths restore varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restoration contracts (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_refactor_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
    capture ado uninstall tabtools
    log close _refactor_contracts
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_refactor_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture ado uninstall tabtools
log close _refactor_contracts
