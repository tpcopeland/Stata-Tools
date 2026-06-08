* table1_tc_fast_aggregate.do - QA for table1_tc fast aggregation helper prototype
* Run from tabtools/qa:
*     stata-mp -b do _package/table1_tc_fast_aggregate.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _all

local qa_dir "`c(pwd)'"
if regexm("`qa_dir'", "/_package$") {
    local qa_dir = regexr("`qa_dir'", "/_package$", "")
}
else if !regexm("`qa_dir'", "/qa$") {
    local qa_dir "`qa_dir'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

log using "`output_dir'/table1_tc_fast_aggregate.log", replace text name(_t1tc_fast_aggregate)

adopath ++ "`pkg_dir'"
which table1_tc
which _tabtools_table1_fast_collect

local result_file "`output_dir'/table1_tc_fast_aggregate_results.tsv"
tempname rf
file open `rf' using "`result_file'", write replace text
file write `rf' "test" _tab "status" _tab "detail" _n

local test_count 0
local pass_count 0
local fail_count 0

capture program drop _t1fa_dataset
program define _t1fa_dataset
    version 16.0
    clear
    set obs 240
    set seed 20260523

    gen long id = _n
    gen byte group = mod(_n, 3)
    gen double age = 45 + 8 * rnormal() + 2 * group
    gen double biomarker = exp(1 + .2 * rnormal() + .1 * group)
    gen double skew = rgamma(2 + group / 3, 2)
    gen byte female = mod(_n, 5) < 3
    gen byte stage = mod(_n, 4)
    gen double iptw = 0.5 + runiform() + group / 10
    gen int fw = cond(mod(_n, 11) == 0, 3, cond(mod(_n, 7) == 0, 2, 1))

    replace age = . if mod(_n, 37) == 0
    replace biomarker = . if mod(_n, 41) == 0
    replace skew = . if mod(_n, 43) == 0
    replace female = . if mod(_n, 47) == 0
    replace stage = . if mod(_n, 53) == 0

    label define group_lbl 0 "Control" 1 "Dose A" 2 "Dose B"
    label values group group_lbl
    label define stage_lbl 0 "Stage 0" 1 "Stage 1" 2 "Stage 2" 3 "Stage 3"
    label values stage stage_lbl
    label variable age "Age"
    label variable biomarker "Biomarker"
    label variable skew "Skewed measure"
    label variable female "Female"
    label variable stage "Clinical stage"
end

capture program drop _t1fa_frame_cell
program define _t1fa_frame_cell, rclass
    version 16.0
    syntax, FRAME(name) ROW(integer) COLUMN(name)
    frame `frame' {
        mata: st_local("_cell", st_sdata(`row', "`column'"))
    }
    return local cell `"`_cell'"'
end

capture program drop _t1fa_data_cell
program define _t1fa_data_cell, rclass
    version 16.0
    syntax, ROW(integer) COLUMN(name)
    mata: st_local("_cell", st_sdata(`row', "`column'"))
    return local cell `"`_cell'"'
end

**# Test 1: unweighted contract and display parity
local ++test_count
tempfile fastout
capture noisily {
    _t1fa_dataset
    capture frame drop t1fa_current
    quietly table1_tc, by(group) ///
        vars(age contn \ female bin \ stage cat) total(after) nopvalue ///
        frame(t1fa_current, replace) format(%9.3f) percformat(%9.3f) nformat(%12.0f)

    _tabtools_table1_fast_collect, by(group) ///
        vars(age contn \ female bin \ stage cat) total(after) nopvalue ///
        saving("`fastout'") stub(group_) format(%9.3f) percformat(%9.3f) nformat(%12.0f)

    use "`fastout'", clear
    confirm variable factor
    confirm variable factor_sep
    confirm variable group_0
    confirm variable group_1
    confirm variable group_2
    confirm variable group_2147483620
    confirm variable N_0
    confirm variable _columna_0
    confirm variable _columnb_0

    assert factor[1] == "N"
    assert factor[2] == "Age"
    assert factor[3] == "Female"
    assert factor[4] == "Clinical stage"
    assert factor[5] == "   Stage 0"

    _t1fa_data_cell, row(1) column(group_0)
    local fast_n0 `"`r(cell)'"'
    _t1fa_frame_cell, frame(t1fa_current) row(2) column(group_0)
    assert strtrim(`"`fast_n0'"') == strtrim(`"`r(cell)'"')

    _t1fa_data_cell, row(2) column(group_0)
    local fast_age0 `"`r(cell)'"'
    _t1fa_frame_cell, frame(t1fa_current) row(3) column(group_0)
    assert strtrim(`"`fast_age0'"') == strtrim(`"`r(cell)'"')

    _t1fa_data_cell, row(3) column(group_1)
    local fast_bin1 `"`r(cell)'"'
    _t1fa_frame_cell, frame(t1fa_current) row(4) column(group_1)
    assert strtrim(`"`fast_bin1'"') == strtrim(`"`r(cell)'"')

    _t1fa_data_cell, row(5) column(group_2)
    local fast_cat2 `"`r(cell)'"'
    _t1fa_frame_cell, frame(t1fa_current) row(6) column(group_2)
    assert strtrim(`"`fast_cat2'"') == strtrim(`"`r(cell)'"')
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `rf' "unweighted_contract_display_parity" _tab "`status'" _tab "N, contn, bin, cat, total(after)" _n

**# Test 2: p-values, test/statistic labels, SMD
local ++test_count
tempfile faststats
capture noisily {
    _t1fa_dataset
    _tabtools_table1_fast_collect, by(group) ///
        vars(age contn \ skew conts \ female bin \ stage cat) ///
        saving("`faststats'") stub(group_) test statistic smd
    use "`faststats'", clear

    count if factor == "Age" & p < . & smd_val < . & test == "ANOVA" & statistic != ""
    assert r(N) == 1
    count if factor == "Skewed measure" & p < . & smd_val < . & test == "Kruskal-Wallis" & statistic != ""
    assert r(N) == 1
    count if factor == "Female" & p < . & smd_val < . & test == "Chi-square" & statistic != ""
    assert r(N) == 1
    count if factor == "Clinical stage" & p < . & smd_val < . & test == "Chi-square" & statistic != ""
    assert r(N) == 1
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `rf' "tests_smd_contract" _tab "`status'" _tab "p, test, statistic, smd for cont/bin/cat" _n

**# Test 3: wt() weighted contract
local ++test_count
tempfile fastwt
capture noisily {
    _t1fa_dataset
    _tabtools_table1_fast_collect, by(group) ///
        vars(age contn \ female bin \ stage cat) wt(iptw) smd total(after) ///
        saving("`fastwt'") stub(group_) format(%9.3f) percformat(%9.3f) nformat(%12.0f) percsign("%")
    use "`fastwt'", clear

    assert factor[1] == "N"
    assert factor[2] == "Effective sample size"
    capture confirm variable p
    assert _rc == 111
    count if inlist(factor, "Age", "Female", "Clinical stage") & smd_val < .
    assert r(N) == 3
    assert strpos(group_0[4], "%") > 0
    assert strpos(group_0[4], "(") == 0
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `rf' "weighted_contract" _tab "`status'" _tab "wt(), ESS, p suppression, weighted SMD, percent default" _n

**# Test 4: missing/category row-percent/slashN formatting
local ++test_count
tempfile fastmissing
capture noisily {
    _t1fa_dataset
    _tabtools_table1_fast_collect, by(group) ///
        vars(stage cat) missing catrowperc percent_n slashN total(after) ///
        saving("`fastmissing'") stub(group_) percformat(%5.1f) nformat(%9.0f) percsign("%")
    use "`fastmissing'", clear

    count if factor == "   Missing" & cat_not_top_row == 1
    assert r(N) == 1
    count if factor == "   Stage 0" & strpos(group_0, "%") > 0 & strpos(group_0, "/") > 0
    assert r(N) == 1
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `rf' "missing_rowpercent_slashn" _tab "`status'" _tab "missing level, row %, percent_n, slashN" _n

**# Test 5: fweight contract
local ++test_count
tempfile fastfw
capture noisily {
    _t1fa_dataset
    quietly summarize fw if group == 0
    local fw_n0 = r(sum)
    _tabtools_table1_fast_collect [fw=fw], by(group) ///
        vars(age contn \ female bin \ stage cat) total(after) ///
        saving("`fastfw'") stub(group_) nformat(%9.0f)
    use "`fastfw'", clear
    assert group_0[1] == "N=" + string(`fw_n0', "%9.0f")
    assert N_0[1] == `fw_n0'
    count if factor == "Age" & N_0 < .
    assert r(N) == 1
}
local rc = _rc
if `rc' == 0 local ++pass_count
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `rf' "fweight_contract" _tab "`status'" _tab "sample N and continuous N honor fweights" _n

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
file close `rf'

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: table1_tc_fast_aggregate tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _t1tc_fast_aggregate
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: table1_tc_fast_aggregate tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as text "Results file: `result_file'"
log close _t1tc_fast_aggregate
