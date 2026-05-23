* test_table1_tc_aggregation_contracts.do - public table1_tc aggregation rewrite QA
* Run from tabtools/qa or tabtools/qa/_package:
*     stata-mp -b do _package/test_table1_tc_aggregation_contracts.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _t1tc_agg_contracts

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local qa_dir "`_cwd'"
}
else {
    local qa_dir "`_cwd'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/_package/output"
capture mkdir "`output_dir'"

log using "`output_dir'/test_table1_tc_aggregation_contracts.log", replace text name(_t1tc_agg_contracts)

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_t1agg_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_t1agg_personal_`install_tag'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

ado dir
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which table1_tc

local checker "`qa_dir'/tools/check_xlsx.py"
capture confirm file "`checker'"
if _rc {
    display as error "check_xlsx.py not found"
    log close _t1tc_agg_contracts
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "python runtime not found"
    log close _t1tc_agg_contracts
    exit 601
}

capture program drop _t1agg_build_data
program define _t1agg_build_data
    version 17.0
    clear
    set obs 12

    gen byte trt = cond(_n <= 6, 0, 1)
    gen double age = .
    replace age = 48 in 1
    replace age = 50 in 2
    replace age = 53 in 3
    replace age = 55 in 4
    replace age = 58 in 5
    replace age = .  in 6
    replace age = 60 in 7
    replace age = 62 in 8
    replace age = 64 in 9
    replace age = 67 in 10
    replace age = 70 in 11
    replace age = 73 in 12

    gen double marker = .
    replace marker = 4 in 1
    replace marker = 5 in 2
    replace marker = 6 in 3
    replace marker = 8 in 4
    replace marker = 9 in 5
    replace marker = . in 6
    replace marker = 7 in 7
    replace marker = 8 in 8
    replace marker = 10 in 9
    replace marker = 12 in 10
    replace marker = 13 in 11
    replace marker = 15 in 12

    gen byte female = .
    replace female = 0 in 1
    replace female = 1 in 2
    replace female = 1 in 3
    replace female = 0 in 4
    replace female = 1 in 5
    replace female = . in 6
    replace female = 1 in 7
    replace female = 0 in 8
    replace female = 1 in 9
    replace female = 1 in 10
    replace female = 0 in 11
    replace female = 1 in 12

    gen byte stage = .
    replace stage = 1 in 1
    replace stage = 1 in 2
    replace stage = 2 in 3
    replace stage = 2 in 4
    replace stage = 3 in 5
    replace stage = . in 6
    replace stage = 1 in 7
    replace stage = 2 in 8
    replace stage = 2 in 9
    replace stage = 3 in 10
    replace stage = 3 in 11
    replace stage = . in 12

    gen double w = 0.75 + mod(_n, 4) / 2
    gen int fw = cond(mod(_n, 5) == 0, 3, cond(mod(_n, 3) == 0, 2, 1))

    label define trtlbl 0 "Control" 1 "Active", replace
    label values trt trtlbl
    label define yesno 0 "No" 1 "Yes", replace
    label values female yesno
    label define stagelbl 1 "Stage I" 2 "Stage II" 3 "Stage III", replace
    label values stage stagelbl

    label variable age "Age at entry"
    label variable marker "Inflammation marker"
    label variable female "Female sex"
    label variable stage "Clinical stage"
    label variable trt "Treatment group"
    label variable w "Analysis weight"
    label variable fw "Frequency weight"
end

capture program drop _t1agg_row
program define _t1agg_row, rclass
    version 17.0
    syntax anything(name=wanted)
    local wanted = subinstr(`"`wanted'"', `"""', "", .)

    tempvar _row
    gen long `_row' = _n
    quietly summarize `_row' if strtrim(factor) == strtrim(`"`wanted'"'), meanonly
    if r(N) != 1 {
        noisily display as error "expected one row for factor `wanted', found " r(N)
        drop `_row'
        exit 459
    }
    return scalar row = r(min)
    drop `_row'
end

capture program drop _t1agg_assert_has
program define _t1agg_assert_has
    version 17.0
    syntax varname, ROW(integer) TEXT(string asis)

    assert strpos(`varlist'[`row'], `"`text'"') > 0
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Unweighted aggregation, p-values/tests/SMD, missing, totals, and labels

local ++test_count
capture noisily {
    _t1agg_build_data
    table1_tc, by(trt) ///
        vars(age contn %6.2f \ marker conts %6.1f \ female bin \ stage cat) ///
        smd test statistic missing total(after) clear nformat(%9.0f) percformat(%5.1f)

    confirm variable factor
    confirm variable trt_0
    confirm variable trt_1
    confirm variable trt_T
    confirm variable pvalue
    confirm variable test
    confirm variable statistic
    confirm variable smd_str
    assert "`: variable label trt_0'" == "Control"
    assert "`: variable label trt_1'" == "Active"
    assert "`: variable label trt_T'" == "Total"
    assert "`: variable label pvalue'" == "p-value"
    assert "`: variable label smd_str'" == "SMD"

    tempname R
    matrix `R' = r(table)
    assert colnumb(`R', "p_value") == 1
    assert colnumb(`R', "smd") == 2
    assert rownumb(`R', "Age_at_entry") < .
    assert el(`R', rownumb(`R', "Age_at_entry"), colnumb(`R', "p_value")) < .
    assert el(`R', rownumb(`R', "Age_at_entry"), colnumb(`R', "smd")) < .

    _t1agg_row "Age at entry"
    local age_row = r(row)
    assert test[`age_row'] == "Ind. t test"
    assert statistic[`age_row'] != ""
    assert pvalue[`age_row'] != ""
    assert smd_str[`age_row'] != ""
    assert trt_T[`age_row'] != ""

    _t1agg_row "Female sex"
    local bin_row = r(row)
    assert test[`bin_row'] == "Chi-square"
    assert strpos(trt_0[`bin_row'], "(") > 0
    assert strpos(trt_1[`bin_row'], "%") > 0

    _t1agg_row "Missing"
    local miss_row = r(row)
    assert strpos(trt_0[`miss_row'], "%") > 0
    assert strpos(trt_1[`miss_row'], "%") > 0
}
if _rc == 0 {
    display as result "  PASS: unweighted aggregation contract covers tests, SMD, missing, totals, and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: unweighted aggregation contract (rc=`=_rc')"
    local ++fail_count
}

**# Percent modes, total placement, and header percentages

local ++test_count
capture noisily {
    _t1agg_build_data
    table1_tc, by(trt) vars(stage cat) total(before) headerperc percent clear ///
        nformat(%9.0f) percformat(%5.1f)
    confirm variable trt_T
    assert "`: variable label trt_T'" == "Total"
    assert strpos(trt_T[2], "100.0%") > 0
    _t1agg_row "Stage II"
    local row = r(row)
    assert strpos(trt_0[`row'], "%") > 0
    assert strpos(trt_0[`row'], "(") == 0

    _t1agg_build_data
    table1_tc, by(trt) vars(stage cat) catrowperc percent_n slashN total(after) ///
        missing clear nformat(%9.0f) percformat(%5.1f)
    _t1agg_row "Stage II"
    local row = r(row)
    assert strpos(trt_0[`row'], "%") > 0
    assert strpos(trt_0[`row'], "/") > 0
    assert strpos(trt_T[`row'], "%") > 0
    _t1agg_row "Missing"
    local row = r(row)
    assert strpos(trt_T[`row'], "%") > 0
}
if _rc == 0 {
    display as result "  PASS: percent, percent_n, slashN, catrowperc, total, and headerperc contracts hold"
    local ++pass_count
}
else {
    display as error "  FAIL: percent-mode and total/header contracts (rc=`=_rc')"
    local ++fail_count
}

**# fweight parity against expanded data

local ++test_count
capture noisily {
    tempfile fwout expandedout

    _t1agg_build_data
    table1_tc [fw=fw], by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        missing total(after) nopvalue clear nformat(%9.0f) percformat(%5.1f)
    gen long rowid = _n
    rename factor fw_factor
    rename trt_0 fw_trt_0
    rename trt_1 fw_trt_1
    rename trt_T fw_trt_T
    keep rowid fw_factor fw_trt_0 fw_trt_1 fw_trt_T
    save "`fwout'", replace

    _t1agg_build_data
    expand fw
    table1_tc, by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        missing total(after) nopvalue clear nformat(%9.0f) percformat(%5.1f)
    gen long rowid = _n
    rename factor ex_factor
    rename trt_0 ex_trt_0
    rename trt_1 ex_trt_1
    rename trt_T ex_trt_T
    keep rowid ex_factor ex_trt_0 ex_trt_1 ex_trt_T
    save "`expandedout'", replace

    use "`fwout'", clear
    merge 1:1 rowid using "`expandedout'", nogen assert(match)
    assert fw_factor == ex_factor
    assert fw_trt_0 == ex_trt_0
    assert fw_trt_1 == ex_trt_1
    assert fw_trt_T == ex_trt_T
}
if _rc == 0 {
    display as result "  PASS: fweight output matches expanded-data output"
    local ++pass_count
}
else {
    display as error "  FAIL: fweight parity contract (rc=`=_rc')"
    local ++fail_count
}

**# wt(), wtcompare, SMD, and weighted p-value suppression

local ++test_count
capture noisily {
    _t1agg_build_data
    table1_tc, by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        wt(w) wtcompare smd total(after) clear nformat(%9.0f) percformat(%5.1f)
    confirm variable Cr_0
    confirm variable Cr_1
    confirm variable Cr_T
    confirm variable Wt_0
    confirm variable Wt_1
    confirm variable Wt_T
    confirm variable smd_str
    capture confirm variable pvalue
    assert _rc == 111
    capture confirm variable test
    local has_test_col = (_rc == 0)
    capture confirm variable statistic
    local has_stat_col = (_rc == 0)
    assert "`: variable label Cr_0'" == "Crude Control"
    assert "`: variable label Wt_0'" == "Weighted Control"
    assert "`: variable label Cr_T'" == "Crude Total"
    assert "`: variable label Wt_T'" == "Weighted Total"

    _t1agg_row "Effective sample size"
    local ess_row = r(row)
    assert Wt_0[`ess_row'] != ""
    assert Wt_1[`ess_row'] != ""
    assert Wt_T[`ess_row'] != ""

    _t1agg_row "Age at entry"
    local age_row = r(row)
    assert Cr_0[`age_row'] != Wt_0[`age_row']
    assert smd_str[`age_row'] != ""

    _t1agg_row "Female sex"
    local bin_row = r(row)
    assert strpos(Cr_0[`bin_row'], "(") > 0
    assert strpos(Wt_0[`bin_row'], "(") > 0
    assert strpos(Wt_0[`bin_row'], "%") > 0
}
if _rc == 0 {
    display as result "  PASS: wtcompare side-by-side columns, ESS, SMD, and p-value suppression hold"
    local ++pass_count
}
else {
    display as error "  FAIL: wtcompare contract (rc=`=_rc')"
    local ++fail_count
}

**# Public Excel style smoke

local ++test_count
capture noisily {
    local xlsx_file "`output_dir'/test_table1_tc_aggregation_contracts.xlsx"
    local check_result "`output_dir'/test_table1_tc_aggregation_contracts_xlsx.txt"
    capture erase "`xlsx_file'"
    capture erase "`check_result'"

    _t1agg_build_data
    table1_tc, by(trt) vars(age contn %6.2f \ female bin \ stage cat) ///
        smd test statistic missing total(after) ///
        xlsx("`xlsx_file'") sheet("Agg Contracts") ///
        title("Table 1 Aggregation Contracts") footnote("Excel style smoke") ///
        theme(lancet) borderstyle(thin) headershade zebra boldp(0.05) ///
        nformat(%9.0f) percformat(%5.1f)
    confirm file "`xlsx_file'"

    shell `python_cmd' "`checker'" "`xlsx_file'" --sheet "Agg Contracts" ///
        --cell A1 "Table 1 Aggregation Contracts" ///
        --contains "Age at entry" --contains "Excel style smoke" ///
        --has-pattern p-values n-equals --merged-row 1 ///
        --has-borders --font Arial --result-file "`check_result'" --quiet
    file open _xfh using "`check_result'", read text
    file read _xfh _line
    file close _xfh
    assert "`_line'" == "PASS"
    capture erase "`xlsx_file'"
    capture erase "`check_result'"
}
if _rc == 0 {
    display as result "  PASS: public Excel style smoke workbook passes semantic/style checks"
    local ++pass_count
}
else {
    display as error "  FAIL: public Excel style smoke (rc=`=_rc')"
    local ++fail_count
}

**# Performance guardrail for aggregation-heavy public command path

local ++test_count
capture noisily {
    clear
    set obs 20000
    set seed 20260523
    gen byte trt = mod(_n, 3)
    gen double age = 50 + 10 * rnormal() + trt
    gen double bmi = 27 + 4 * rnormal()
    gen double marker = exp(1 + .15 * rnormal() + .05 * trt)
    gen byte female = runiform() > .48
    gen byte smoker = runiform() > .70
    gen byte stage = floor(4 * runiform())
    replace age = . if mod(_n, 97) == 0
    replace bmi = . if mod(_n, 89) == 0
    replace marker = . if mod(_n, 83) == 0
    replace female = . if mod(_n, 113) == 0
    replace smoker = . if mod(_n, 127) == 0
    replace stage = . if mod(_n, 131) == 0
    label define trt3 0 "Control" 1 "Dose A" 2 "Dose B", replace
    label values trt trt3
    label define stage4 0 "Stage 0" 1 "Stage 1" 2 "Stage 2" 3 "Stage 3", replace
    label values stage stage4

    timer clear 91
    timer on 91
    quietly table1_tc, by(trt) vars(age contn \ bmi contn \ marker conts \ ///
        female bin \ smoker bin \ stage cat) total(after) nopvalue clear ///
        nformat(%9.0f) percformat(%5.1f)
    timer off 91
    quietly timer list 91
    local elapsed = r(t91)
    display as text "table1_tc aggregation performance guardrail elapsed seconds: `elapsed'"
    assert `elapsed' < 30
    confirm variable trt_T
}
if _rc == 0 {
    display as result "  PASS: aggregation performance guardrail stays below 30 seconds"
    local ++pass_count
}
else {
    display as error "  FAIL: aggregation performance guardrail (rc=`=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_table1_tc_aggregation_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _t1tc_agg_contracts
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_table1_tc_aggregation_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _t1tc_agg_contracts
