* save_style_engine_before_fixtures.do - capture current Excel style fixtures
* Run from tabtools/qa or tabtools/qa/_package:
*     stata-mp -b do _package/save_style_engine_before_fixtures.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _sse_before

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
local output_dir "`qa_dir'/output/shared_style_engine"
local before_dir "`output_dir'/before"
capture mkdir "`qa_dir'/output"
capture mkdir "`output_dir'"
capture mkdir "`before_dir'"

log using "`output_dir'/save_style_engine_before_fixtures.log", replace text name(_sse_before)

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_sse_before_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_sse_before_personal_`install_tag'"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

display as text "ado dir before isolated tabtools install:"
ado dir
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
confirm file "`pkg_dir'/tabtools.pkg"
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

capture program drop _sse_make_strate
program define _sse_make_strate
    syntax , BASENAME(string)
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 18)
    gen double _Y = cond(_n == 1, 1000, 1200)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _sse_exp 0 "None" 1 "Current", replace
    label values exposure _sse_exp
    save "`basename'.dta", replace
end

local manifest "`output_dir'/shared_style_engine_before_manifest.tsv"
tempname mf
file open `mf' using "`manifest'", write text replace
file write `mf' "command" _tab "sheet" _tab "file" _tab "status" _tab "rc" _tab "notes" _n

local fail_count 0
local created_files ""

foreach cmd in regtab effecttab desctab table1_tc corrtab crosstab survtab diagtab comptab stratetab hrcomptab {
    capture erase "`before_dir'/before_`cmd'.xlsx"
}

**# regtab
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    regtab, xlsx("`before_dir'/before_regtab.xlsx") sheet("Reg") ///
        title("Shared Style Regtab") noint theme(lancet) headershade zebra
    confirm file "`before_dir'/before_regtab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_regtab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "regtab" _tab "Reg" _tab "before_regtab.xlsx" _tab "`status'" _tab "`rc'" _tab "regression table with title, header fill, zebra, borders" _n

**# effecttab
capture noisily {
    matrix _sse_eff = (1.50, 0.80, 2.20, 0.04 \ 2.30, 1.10, 3.50, 0.001)
    matrix rownames _sse_eff = Age Sex
    effecttab, from(_sse_eff) xlsx("`before_dir'/before_effecttab.xlsx") ///
        sheet("Effects") title("Shared Style Effecttab") effect("OR") ///
        theme(lancet) headershade zebra boldp(0.05)
    confirm file "`before_dir'/before_effecttab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_effecttab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "effecttab" _tab "Effects" _tab "before_effecttab.xlsx" _tab "`status'" _tab "`rc'" _tab "matrix effects with CI, p-values, boldp fill" _n

**# desctab
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)
    desctab, xlsx("`before_dir'/before_desctab.xlsx") sheet("Desc") ///
        title("Shared Style Desctab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_desctab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_desctab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "desctab" _tab "Desc" _tab "before_desctab.xlsx" _tab "`status'" _tab "`rc'" _tab "collect descriptive table with row and column headers" _n

**# table1_tc
capture noisily {
    sysuse auto, clear
    gen byte highrep = rep78 >= 4 if !missing(rep78)
    table1_tc price mpg foreign, vars(price contn \ mpg contn \ foreign bin) ///
        by(highrep) xlsx("`before_dir'/before_table1_tc.xlsx") sheet("Table1") ///
        title("Shared Style Table1") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_table1_tc.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_table1_tc.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "table1_tc" _tab "Table1" _tab "before_table1_tc.xlsx" _tab "`status'" _tab "`rc'" _tab "baseline table with continuous and binary rows" _n

**# corrtab
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length, pvalues xlsx("`before_dir'/before_corrtab.xlsx") ///
        sheet("Corr") title("Shared Style Corrtab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_corrtab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_corrtab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "corrtab" _tab "Corr" _tab "before_corrtab.xlsx" _tab "`status'" _tab "`rc'" _tab "correlation matrix with p-values and matrix-style layout" _n

**# crosstab
capture noisily {
    sysuse auto, clear
    crosstab rep78 foreign, xlsx("`before_dir'/before_crosstab.xlsx") ///
        sheet("Cross") title("Shared Style Crosstab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_crosstab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_crosstab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "crosstab" _tab "Cross" _tab "before_crosstab.xlsx" _tab "`status'" _tab "`rc'" _tab "cross-tab with percentages and summary rows" _n

**# survtab
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) xlsx("`before_dir'/before_survtab.xlsx") ///
        sheet("Surv") title("Shared Style Survtab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_survtab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_survtab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "survtab" _tab "Surv" _tab "before_survtab.xlsx" _tab "`status'" _tab "`rc'" _tab "survival estimates with group columns and log-rank rows" _n

**# diagtab
capture noisily {
    clear
    input byte(test gold)
    1 1
    1 1
    1 0
    0 0
    0 1
    0 0
    end
    diagtab test gold, xlsx("`before_dir'/before_diagtab.xlsx") ///
        sheet("Diag") title("Shared Style Diagtab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_diagtab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_diagtab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "diagtab" _tab "Diag" _tab "before_diagtab.xlsx" _tab "`status'" _tab "`rc'" _tab "diagnostic 2x2 metrics table" _n

**# stratetab
tempfile rate1
capture noisily {
    _sse_make_strate, basename("`rate1'")
    capture frame drop _sse_rates
    stratetab, using("`rate1'") outcomes(1) ///
        xlsx("`before_dir'/before_stratetab.xlsx") sheet("Rates") ///
        title("Shared Style Stratetab") frame(_sse_rates, replace) ///
        theme(lancet) headershade zebra
    confirm file "`before_dir'/before_stratetab.xlsx"
}
local rc = _rc
if `rc' == 0 local created_files `"`created_files' `before_dir'/before_stratetab.xlsx"'
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "stratetab" _tab "Rates" _tab "before_stratetab.xlsx" _tab "`status'" _tab "`rc'" _tab "rate table fixture also feeds hrcomptab" _n

**# comptab and hrcomptab
capture noisily {
    sysuse auto, clear
    collect clear
    gen byte treated = foreign
    collect: regress price treated mpg weight
    capture frame drop _sse_model
    regtab, frame(_sse_model) noint title("Shared Style Source Regtab")

    comptab _sse_model, rows(1) xlsx("`before_dir'/before_comptab.xlsx") ///
        sheet("Comp") title("Shared Style Comptab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_comptab.xlsx"

    hrcomptab _sse_rates, modelframes(_sse_model) rows(1) ///
        xlsx("`before_dir'/before_hrcomptab.xlsx") sheet("HR") ///
        title("Shared Style Hrcomptab") theme(lancet) headershade zebra
    confirm file "`before_dir'/before_hrcomptab.xlsx"
}
local rc = _rc
if `rc' == 0 {
    local created_files `"`created_files' `before_dir'/before_comptab.xlsx `before_dir'/before_hrcomptab.xlsx"'
}
else local ++fail_count
local status = cond(`rc' == 0, "PASS", "FAIL")
file write `mf' "comptab" _tab "Comp" _tab "before_comptab.xlsx" _tab "`status'" _tab "`rc'" _tab "composite of regtab frame" _n
file write `mf' "hrcomptab" _tab "HR" _tab "before_hrcomptab.xlsx" _tab "`status'" _tab "`rc'" _tab "rate/model composite table" _n

file close `mf'

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard

display as result "Created before fixtures:"
foreach created_file of local created_files {
    display as text "  `created_file'"
}
display as result "Manifest: `manifest'"
display "RESULT: save_style_engine_before_fixtures fail=`fail_count'"

log close _sse_before
if `fail_count' > 0 exit 1
