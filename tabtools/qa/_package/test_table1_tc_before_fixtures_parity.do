* test_table1_tc_before_fixtures_parity.do - compare rewritten table1_tc to saved legacy fixtures
* Run from tabtools/qa or tabtools/qa/_package:
*     stata-mp -b do _package/test_table1_tc_before_fixtures_parity.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _t1tc_fixture_parity

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
local output_dir "`qa_dir'/output/before_after"
capture mkdir "`qa_dir'/output"
capture mkdir "`output_dir'"

log using "`output_dir'/test_table1_tc_before_fixtures_parity.log", replace text name(_t1tc_fixture_parity)

local before_fixtures ///
    before_unweighted_baseline.tsv ///
    before_weighted_wt.tsv ///
    before_wtcompare.tsv ///
    before_smd_test_statistic.tsv ///
    before_missing_labels.tsv ///
    before_total_before.tsv ///
    before_total_after.tsv ///
    before_col_percent.tsv ///
    before_percent_n.tsv ///
    before_row_percent_slashn.tsv ///
    before_fweight.tsv

local missing_fixture 0
foreach before_fixture of local before_fixtures {
    capture confirm file "`output_dir'/`before_fixture'"
    if _rc local missing_fixture 1
}
if `missing_fixture' {
    display as text "SKIP: saved before fixtures not found; run _package/save_table1_tc_before_fixtures.do before strict parity comparison"
    display "RESULT: test_table1_tc_before_fixtures_parity tests=0 pass=0 fail=0 skip=1"
    log close _t1tc_fixture_parity
    exit 0
}

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_t1parity_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_t1parity_personal_`install_tag'"
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
which _tabtools_table1_fast_collect

capture program drop _t1tc_fixture_data
program define _t1tc_fixture_data
    version 17.0
    clear
    set obs 14
    gen long id = _n
    gen byte trt = cond(_n <= 7, 0, 1)

    gen double age = .
    replace age = 48 in 1
    replace age = 52 in 2
    replace age = 57 in 3
    replace age = 61 in 4
    replace age = 63 in 5
    replace age = 66 in 6
    replace age = .  in 7
    replace age = 50 in 8
    replace age = 55 in 9
    replace age = 59 in 10
    replace age = 64 in 11
    replace age = 68 in 12
    replace age = 71 in 13
    replace age = 73 in 14

    gen double crp = .
    replace crp = 1.2 in 1
    replace crp = 1.7 in 2
    replace crp = 2.0 in 3
    replace crp = 2.5 in 4
    replace crp = 3.2 in 5
    replace crp = .   in 6
    replace crp = 4.6 in 7
    replace crp = 1.5 in 8
    replace crp = 2.1 in 9
    replace crp = 2.9 in 10
    replace crp = 4.1 in 11
    replace crp = 5.4 in 12
    replace crp = 7.2 in 13
    replace crp = .   in 14

    gen double hosp = .
    replace hosp = 0 in 1
    replace hosp = 1 in 2
    replace hosp = 2 in 3
    replace hosp = 1 in 4
    replace hosp = 4 in 5
    replace hosp = 3 in 6
    replace hosp = 8 in 7
    replace hosp = 0 in 8
    replace hosp = 2 in 9
    replace hosp = 3 in 10
    replace hosp = 1 in 11
    replace hosp = 5 in 12
    replace hosp = 7 in 13
    replace hosp = 9 in 14

    gen byte female = .
    replace female = 0 in 1
    replace female = 1 in 2
    replace female = 1 in 3
    replace female = 0 in 4
    replace female = 1 in 5
    replace female = 0 in 6
    replace female = . in 7
    replace female = 1 in 8
    replace female = 1 in 9
    replace female = 0 in 10
    replace female = 1 in 11
    replace female = 0 in 12
    replace female = 1 in 13
    replace female = 1 in 14

    gen byte stage = .
    replace stage = 1 in 1
    replace stage = 1 in 2
    replace stage = 2 in 3
    replace stage = 2 in 4
    replace stage = 3 in 5
    replace stage = . in 6
    replace stage = 3 in 7
    replace stage = 1 in 8
    replace stage = 2 in 9
    replace stage = 2 in 10
    replace stage = 3 in 11
    replace stage = 3 in 12
    replace stage = 4 in 13
    replace stage = . in 14

    gen byte smoking = .
    replace smoking = 0 in 1
    replace smoking = 1 in 2
    replace smoking = 2 in 3
    replace smoking = 1 in 4
    replace smoking = . in 5
    replace smoking = 0 in 6
    replace smoking = 2 in 7
    replace smoking = 1 in 8
    replace smoking = 1 in 9
    replace smoking = 2 in 10
    replace smoking = 2 in 11
    replace smoking = 0 in 12
    replace smoking = . in 13
    replace smoking = 1 in 14

    gen double iptw = .
    replace iptw = 1.0 in 1
    replace iptw = 1.4 in 2
    replace iptw = 0.8 in 3
    replace iptw = 1.7 in 4
    replace iptw = 0.6 in 5
    replace iptw = 1.2 in 6
    replace iptw = 2.1 in 7
    replace iptw = 0.9 in 8
    replace iptw = 1.5 in 9
    replace iptw = 1.1 in 10
    replace iptw = 0.7 in 11
    replace iptw = 1.8 in 12
    replace iptw = 0.5 in 13
    replace iptw = 2.3 in 14

    gen int fwt = 1
    replace fwt = 2 in 2
    replace fwt = 3 in 5
    replace fwt = 2 in 9
    replace fwt = 3 in 12

    label define trtlbl 0 "Usual care" 1 "Intervention", replace
    label values trt trtlbl
    label define yesno 0 "No" 1 "Yes", replace
    label values female yesno
    label define stagelbl 1 "Stage I" 2 "Stage II" 3 "Stage III" 4 "Stage IV", replace
    label values stage stagelbl
    label define smokelbl 0 "Never" 1 "Former" 2 "Current", replace
    label values smoking smokelbl

    label variable trt "Treatment arm"
    label variable age "Age at index"
    label variable crp "C-reactive protein"
    label variable hosp "Prior hospitalizations"
    label variable female "Female sex"
    label variable stage "Cancer stage"
    label variable smoking "Smoking status"
    label variable iptw "Stabilized IPTW"
    label variable fwt "Frequency weight"
end

capture program drop _t1tc_compare_tsv
program define _t1tc_compare_tsv
    version 17.0
    syntax using/, AFTER(string)

    tempfile before current
    export delimited using "`current'", replace delimiter(tab)
    export delimited using "`after'", replace delimiter(tab)
    preserve
    import delimited using "`using'", clear delimiter(tab) varnames(1) stringcols(_all)
    quietly compress
    save "`before'", replace
    restore
    import delimited using "`current'", clear delimiter(tab) varnames(1) stringcols(_all)
    quietly compress
    cf _all using "`before'", all
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Legacy fixture parity cases

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(age contn %6.1f \ female bin \ stage cat) ///
        clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_unweighted_baseline.tsv", ///
        after("`output_dir'/after_unweighted_baseline.tsv")
}
if _rc == 0 {
    display as result "  PASS: unweighted baseline matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: unweighted baseline parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ female bin \ stage cat) ///
        wt(iptw) smd missing percent_n clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_weighted_wt.tsv", ///
        after("`output_dir'/after_weighted_wt.tsv")
}
if _rc == 0 {
    display as result "  PASS: wt() output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: wt() parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ female bin \ stage cat) ///
        wt(iptw) wtcompare smd headerperc clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_wtcompare.tsv", ///
        after("`output_dir'/after_wtcompare.tsv")
}
if _rc == 0 {
    display as result "  PASS: wtcompare output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: wtcompare parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ hosp conts \ female bin \ stage cat) ///
        smd test statistic clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_smd_test_statistic.tsv", ///
        after("`output_dir'/after_smd_test_statistic.tsv")
}
if _rc == 0 {
    display as result "  PASS: SMD/test/statistic output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: SMD/test/statistic parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(stage cat \ smoking cate \ female bin) ///
        missing missingsummary varlabplus clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_missing_labels.tsv", ///
        after("`output_dir'/after_missing_labels.tsv")
}
if _rc == 0 {
    display as result "  PASS: missing and label output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: missing/label parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(age contn %6.1f \ female bin \ stage cat) ///
        total(before) headerperc clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_total_before.tsv", ///
        after("`output_dir'/after_total_before.tsv")
}
if _rc == 0 {
    display as result "  PASS: total(before) output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: total(before) parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(age contn %6.1f \ female bin \ stage cat) ///
        total(after) headerperc clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_total_after.tsv", ///
        after("`output_dir'/after_total_after.tsv")
}
if _rc == 0 {
    display as result "  PASS: total(after) output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: total(after) parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(stage cat \ smoking cate) ///
        missing clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_col_percent.tsv", ///
        after("`output_dir'/after_col_percent.tsv")
}
if _rc == 0 {
    display as result "  PASS: column percent output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: column percent parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(stage cat \ smoking cate) ///
        missing percent_n clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_percent_n.tsv", ///
        after("`output_dir'/after_percent_n.tsv")
}
if _rc == 0 {
    display as result "  PASS: percent_n output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: percent_n parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc, by(trt) vars(stage cat \ smoking cate) ///
        missing catrowperc slashN percent_n clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_row_percent_slashn.tsv", ///
        after("`output_dir'/after_row_percent_slashn.tsv")
}
if _rc == 0 {
    display as result "  PASS: row percent/slashN output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: row percent/slashN parity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _t1tc_fixture_data
    table1_tc [fw=fwt], by(trt) vars(age contn %6.1f \ hosp conts \ female bin \ stage cat) ///
        smd test statistic total(after) clear nformat(%9.0f) percformat(%5.1f)
    _t1tc_compare_tsv using "`output_dir'/before_fweight.tsv", ///
        after("`output_dir'/after_fweight.tsv")
}
if _rc == 0 {
    display as result "  PASS: fweight output matches saved before fixture"
    local ++pass_count
}
else {
    display as error "  FAIL: fweight parity (rc=`=_rc')"
    local ++fail_count
}

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_table1_tc_before_fixtures_parity tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t1tc_fixture_parity
    exit 1
}

display as result "ALL TESTS PASSED"
log close _t1tc_fixture_parity
