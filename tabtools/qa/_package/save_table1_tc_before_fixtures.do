* save_table1_tc_before_fixtures.do - capture current table1_tc before fixtures
* Run from tabtools/qa or tabtools/qa/_package:
*     stata-mp -b do _package/save_table1_tc_before_fixtures.do

clear all
set more off
set varabbrev off
version 17.0
args source_pkg_dir source_label

capture log close _t1tc_before

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
if `"`source_pkg_dir'"' != "" {
    local pkg_dir `"`source_pkg_dir'"'
}
local output_dir "`qa_dir'/output/before_after"
capture mkdir "`qa_dir'/output"
capture mkdir "`output_dir'"

log using "`output_dir'/save_table1_tc_before_fixtures.log", replace text name(_t1tc_before)

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_t1tc_before_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_t1tc_before_personal_`install_tag'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

ado dir
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
confirm file "`pkg_dir'/tabtools.pkg"
quietly net install tabtools, from("`pkg_dir'") replace
discard
which table1_tc
capture findfile table1_tc.ado
local installed_table1_tc_ado "`r(fn)'"
local table1_tc_source "table1_tc.ado from isolated local net install"
if `"`source_label'"' != "" {
    local table1_tc_source `"`source_label'"'
}

local fixtures ///
    "before_unweighted_baseline.tsv" ///
    "before_weighted_wt.tsv" ///
    "before_wtcompare.tsv" ///
    "before_smd_test_statistic.tsv" ///
    "before_missing_labels.tsv" ///
    "before_total_before.tsv" ///
    "before_total_after.tsv" ///
    "before_col_percent.tsv" ///
    "before_percent_n.tsv" ///
    "before_row_percent_slashn.tsv" ///
    "before_fweight.tsv" ///
    "before_excel_formatting_source.tsv" ///
    "before_excel_formatting.xlsx"

foreach fixture of local fixtures {
    capture erase "`output_dir'/`fixture'"
}

capture program drop _t1tc_before_data
program define _t1tc_before_data
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

local manifest "`output_dir'/table1_tc_before_manifest.tsv"
tempname mf
file open `mf' using "`manifest'", write text replace
file write `mf' "case" _tab "kind" _tab "file" _tab "status" _tab "rc" _tab "source_ado" _tab "notes" _n

local fail_count 0
local created_files ""

**# Unweighted baseline
local case "unweighted_baseline"
local outfile "`output_dir'/before_unweighted_baseline.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ female bin \ stage cat) ///
        clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_unweighted_baseline.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "unweighted by(), requested contn/bin/cat spec, current emitted output" _n

**# wt() weighted output
local case "weighted_wt"
local outfile "`output_dir'/before_weighted_wt.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ female bin \ stage cat) ///
        wt(iptw) smd missing percent_n clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_weighted_wt.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "wt(), SMD, missing, percent_n, current emitted output" _n

**# wtcompare output
local case "wtcompare"
local outfile "`output_dir'/before_wtcompare.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ female bin \ stage cat) ///
        wt(iptw) wtcompare smd headerperc clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_wtcompare.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "wtcompare with crude/weighted columns, SMD, headerperc" _n

**# SMD, test, statistic
local case "smd_test_statistic"
local outfile "`output_dir'/before_smd_test_statistic.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ hosp conts \ female bin \ stage cat) ///
        smd test statistic clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_smd_test_statistic.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "smd, test, statistic, requested contn/contln/conts/bin/cat spec, current emitted output" _n

**# Missing rows and labels
local case "missing_labels"
local outfile "`output_dir'/before_missing_labels.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(stage cat \ smoking cate \ female bin) ///
        missing missingsummary varlabplus clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_missing_labels.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "missing, missingsummary, value labels, varlabplus" _n

**# Total before
local case "total_before"
local outfile "`output_dir'/before_total_before.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ female bin \ stage cat) ///
        total(before) headerperc clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_total_before.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "total(before), headerperc" _n

**# Total after
local case "total_after"
local outfile "`output_dir'/before_total_after.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ female bin \ stage cat) ///
        total(after) headerperc clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_total_after.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "total(after), headerperc" _n

**# Column percentage default
local case "col_percent"
local outfile "`output_dir'/before_col_percent.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(stage cat \ smoking cate) ///
        missing clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_col_percent.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "default n (column %) categorical output" _n

**# Percent before N
local case "percent_n"
local outfile "`output_dir'/before_percent_n.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(stage cat \ smoking cate) ///
        missing percent_n clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_percent_n.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "percent_n percentage-count formatting" _n

**# Row percentage and slash-N
local case "row_percent_slashn"
local outfile "`output_dir'/before_row_percent_slashn.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(stage cat \ smoking cate) ///
        missing catrowperc slashN percent_n clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_row_percent_slashn.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "catrowperc row %, slashN, percent_n" _n

**# fweights
local case "fweight"
local outfile "`output_dir'/before_fweight.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc [fw=fwt], by(trt) vars(age contn %6.1f \ hosp conts \ female bin \ stage cat) ///
        smd test statistic total(after) clear nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outfile'", replace delimiter(tab)
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outfile'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "tsv" _tab "before_fweight.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "fweight syntax with total(after), SMD, test, statistic, current emitted output" _n

**# Excel formatting sample
local case "excel_formatting"
local outxlsx "`output_dir'/before_excel_formatting.xlsx"
local outtsv "`output_dir'/before_excel_formatting_source.tsv"
capture noisily {
    _t1tc_before_data
    table1_tc, by(trt) vars(age contn %6.1f \ crp contln %6.2f \ hosp conts \ female bin \ stage cat) ///
        smd test statistic missing total(after) clear ///
        xlsx("`outxlsx'") sheet("Before") ///
        title("Table 1 before aggregation rewrite") ///
        footnote("Current table1_tc output captured before fast aggregation rewrite.") ///
        theme(lancet) borderstyle(academic) headershade zebra boldp(0.05) highlight(0.05) ///
        smdthreshold(0.2) nformat(%9.0f) percformat(%5.1f)
    export delimited using "`outtsv'", replace delimiter(tab)
    confirm file "`outxlsx'"
}
local rc = _rc
if `rc' == 0 {
    local status "PASS"
    local created_files `"`created_files' `outxlsx' `outtsv'"'
}
else {
    local status "FAIL"
    local ++fail_count
}
file write `mf' "`case'" _tab "xlsx+tsv" _tab "before_excel_formatting.xlsx;before_excel_formatting_source.tsv" _tab "`status'" _tab "`rc'" _tab "`table1_tc_source'" _tab "Excel formatting sample plus clear-source TSV" _n

file close `mf'
confirm file "`manifest'"

display as result "Created before fixture manifest: `manifest'"
display as result "Fixture failures: `fail_count'"
display as text "Created fixtures:"
foreach created of local created_files {
    display as text "  `created'"
}

capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

if `fail_count' > 0 {
    display as error "SOME FIXTURE CASES FAILED"
    display "RESULT: save_table1_tc_before_fixtures fail=`fail_count'"
    log close _t1tc_before
    exit 1
}

display as result "ALL FIXTURE CASES PASSED"
display "RESULT: save_table1_tc_before_fixtures fail=`fail_count'"
log close _t1tc_before
