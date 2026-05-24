* test_shared_style_engine_after_migration.do - compare current output to saved before fixtures
* Run from tabtools/qa or tabtools/qa/_package after saving before fixtures:
*     stata-mp -b do _package/test_shared_style_engine_after_migration.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _sse_after

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
local after_dir "`output_dir'/after"
capture mkdir "`qa_dir'/output"
capture mkdir "`output_dir'"
capture mkdir "`after_dir'"

log using "`output_dir'/test_shared_style_engine_after_migration.log", replace text name(_sse_after)

local comparator "`qa_dir'/_package/test_shared_style_engine_compare.py"
capture confirm file "`comparator'"
if _rc {
    display as error "FAIL: test_shared_style_engine_compare.py not available"
    log close _sse_after
    exit 601
}

local python_cmd ""
capture noisily shell python3 -c "import openpyxl"
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python -c "import openpyxl"
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "FAIL: python with openpyxl is required for workbook style comparison"
    log close _sse_after
    exit 601
}

local command_list regtab effecttab desctab table1_tc corrtab crosstab survtab diagtab comptab stratetab hrcomptab
local missing_fixture 0
foreach cmd of local command_list {
    capture confirm file "`before_dir'/before_`cmd'.xlsx"
    if _rc local missing_fixture 1
}
if `missing_fixture' {
    display as text "SKIP: saved before fixtures not found; run _package/save_style_engine_before_fixtures.do before strict shared-style comparison"
    display "RESULT: test_shared_style_engine_after_migration tests=0 pass=0 fail=0 skip=1"
    log close _sse_after
    exit 0
}

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_sse_after_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_sse_after_personal_`install_tag'"
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

foreach cmd of local command_list {
    capture erase "`after_dir'/after_`cmd'.xlsx"
    capture erase "`after_dir'/compare_`cmd'.txt"
    capture erase "`after_dir'/compare_`cmd'.json"
}

**# Generate after-migration workbooks
sysuse auto, clear
collect clear
collect: regress price foreign mpg weight
regtab, xlsx("`after_dir'/after_regtab.xlsx") sheet("Reg") ///
    title("Shared Style Regtab") noint theme(lancet) headershade zebra

matrix _sse_eff = (1.50, 0.80, 2.20, 0.04 \ 2.30, 1.10, 3.50, 0.001)
matrix rownames _sse_eff = Age Sex
effecttab, from(_sse_eff) xlsx("`after_dir'/after_effecttab.xlsx") ///
    sheet("Effects") title("Shared Style Effecttab") effect("OR") ///
    theme(lancet) headershade zebra boldp(0.05)

sysuse auto, clear
collect clear
collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)
desctab, xlsx("`after_dir'/after_desctab.xlsx") sheet("Desc") ///
    title("Shared Style Desctab") theme(lancet) headershade zebra

sysuse auto, clear
gen byte highrep = rep78 >= 4 if !missing(rep78)
table1_tc price mpg foreign, vars(price contn \ mpg contn \ foreign bin) ///
    by(highrep) xlsx("`after_dir'/after_table1_tc.xlsx") sheet("Table1") ///
    title("Shared Style Table1") theme(lancet) headershade zebra

sysuse auto, clear
corrtab price mpg weight length, pvalues xlsx("`after_dir'/after_corrtab.xlsx") ///
    sheet("Corr") title("Shared Style Corrtab") theme(lancet) headershade zebra

sysuse auto, clear
crosstab rep78 foreign, xlsx("`after_dir'/after_crosstab.xlsx") ///
    sheet("Cross") title("Shared Style Crosstab") theme(lancet) headershade zebra

webuse drugtr, clear
stset studytime, failure(died)
survtab, times(10 20 30) by(drug) xlsx("`after_dir'/after_survtab.xlsx") ///
    sheet("Surv") title("Shared Style Survtab") theme(lancet) headershade zebra

clear
input byte(test gold)
1 1
1 1
1 0
0 0
0 1
0 0
end
diagtab test gold, xlsx("`after_dir'/after_diagtab.xlsx") ///
    sheet("Diag") title("Shared Style Diagtab") theme(lancet) headershade zebra

tempfile rate1
_sse_make_strate, basename("`rate1'")
capture frame drop _sse_rates
stratetab, using("`rate1'") outcomes(1) ///
    xlsx("`after_dir'/after_stratetab.xlsx") sheet("Rates") ///
    title("Shared Style Stratetab") frame(_sse_rates, replace) ///
    theme(lancet) headershade zebra

sysuse auto, clear
collect clear
gen byte treated = foreign
collect: regress price treated mpg weight
capture frame drop _sse_model
regtab, frame(_sse_model) noint title("Shared Style Source Regtab")

comptab _sse_model, rows(1) xlsx("`after_dir'/after_comptab.xlsx") ///
    sheet("Comp") title("Shared Style Comptab") theme(lancet) headershade zebra

hrcomptab _sse_rates, modelframes(_sse_model) rows(1) ///
    xlsx("`after_dir'/after_hrcomptab.xlsx") sheet("HR") ///
    title("Shared Style Hrcomptab") theme(lancet) headershade zebra

local test_count = 0
local pass_count = 0
local fail_count = 0

local sheet_regtab "Reg"
local sheet_effecttab "Effects"
local sheet_desctab "Desc"
local sheet_table1_tc "Table1"
local sheet_corrtab "Corr"
local sheet_crosstab "Cross"
local sheet_survtab "Surv"
local sheet_diagtab "Diag"
local sheet_comptab "Comp"
local sheet_stratetab "Rates"
local sheet_hrcomptab "HR"

**# Compare values, styles, merges, borders, and fills
foreach cmd of local command_list {
    local ++test_count
    local sheet "`sheet_`cmd''"
    capture noisily {
        confirm file "`after_dir'/after_`cmd'.xlsx"
        shell `python_cmd' "`comparator'" ///
            "`before_dir'/before_`cmd'.xlsx" ///
            "`after_dir'/after_`cmd'.xlsx" ///
            --sheet "`sheet'" ///
            --result-file "`after_dir'/compare_`cmd'.txt" ///
            --report-file "`after_dir'/compare_`cmd'.json"
        file open _fh using "`after_dir'/compare_`cmd'.txt", read text
        file read _fh _line
        file close _fh
        assert "`_line'" == "PASS"
    }
    if _rc == 0 {
        display as result "  PASS: `cmd' workbook matches before fixture values/styles/merges/borders/fills"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `cmd' workbook differs from before fixture (rc=`=_rc')"
        local ++fail_count
    }
}

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard

display as result "Shared style-engine after-migration summary: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_shared_style_engine_after_migration tests=`test_count' pass=`pass_count' fail=`fail_count'"

log close _sse_after
if `fail_count' > 0 exit 1
