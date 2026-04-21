* refactor_baseline.do — generate workbook baselines for the tabtools refactor

capture log close _refactor_baseline
log using "refactor_baseline.log", replace text name(_refactor_baseline)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local baseline_dir "`qa_dir'/baseline"
local workbook_dir "`baseline_dir'/workbooks"
local summary_dir "`baseline_dir'/summaries"
local manifest_file "`baseline_dir'/baseline_manifest.tsv"
local summary_tool "`qa_dir'/tools/summarize_xlsx.py"

capture mkdir "`baseline_dir'"
capture mkdir "`workbook_dir'"
capture mkdir "`summary_dir'"

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
tabtools set clear

tempfile baseline_manifest_data
tempname posth
postfile `posth' str48 scenario str16 command str8 status str244 xlsx ///
    str32 sheet double N_rows double N_cols byte methods_present ///
    str244 summary_file str244 note using `baseline_manifest_data', replace

capture program drop _rb_write_status
program define _rb_write_status
    version 16.0
    syntax , OUTFILE(string) STATUS(string) MESSAGE(string)
    tempname fh
    file open `fh' using "`outfile'", write text replace
    file write `fh' "status\tmessage" _n `"`status'\t`message'"' _n
    file close `fh'
end

capture program drop _rb_write_summary
program define _rb_write_summary
    version 16.0
    syntax , XLSX(string) SHEET(string) OUTFILE(string) [PYCMD(string) TOOL(string)]
    if "`pycmd'" != "" & "`tool'" != "" {
        capture noisily shell `pycmd' "`tool'" "`xlsx'" --sheet "`sheet'" --result-file "`outfile'"
        if _rc == 0 exit
    }
    _rb_write_status, outfile("`outfile'") status("SKIP") ///
        message("python/openpyxl summary unavailable")
end

capture program drop _rb_post_case
program define _rb_post_case
    version 16.0
    syntax , POSTNAME(name) SCENARIO(string) COMMAND(string) STATUS(string) ///
        XLSX(string) SHEET(string) SUMMARYFILE(string) NOTE(string)

    local nrows = .
    local ncols = .
    local methods_present = 0

    if "`status'" == "PASS" {
        capture local __nrows = r(N_rows)
        if _rc == 0 & "`__nrows'" != "" {
            local nrows = real("`__nrows'")
        }
        capture local __ncols = r(N_cols)
        if _rc == 0 & "`__ncols'" != "" {
            local ncols = real("`__ncols'")
        }
        capture local __methods `"`r(methods)'"'
        if _rc == 0 & `"`__methods'"' != "" {
            local methods_present = 1
        }
    }

    post `postname' ("`scenario'") ("`command'") ("`status'") ///
        (`"`xlsx'"') (`"`sheet'"') (`nrows') (`ncols') ///
        (`methods_present') (`"`summaryfile'"') (`"`note'"')
end

local case_count = 0
local pass_count = 0
local fail_count = 0
local failed_cases ""

* =========================================================================
**# corrtab
* =========================================================================

local ++case_count
local scenario "corrtab_spearman_lower"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Corr"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length, spearman lower pvalues ///
        xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: corrtab")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("corrtab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") ///
        note("Spearman lower triangle with p-values")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("corrtab baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("corrtab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") ///
        note("Spearman lower triangle with p-values")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# crosstab
* =========================================================================

local ++case_count
local scenario "crosstab_2x2_chi2"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Cross2x2"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    crosstab outcome exposure, xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: crosstab 2x2")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("crosstab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("2x2 with chi-squared row")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("crosstab 2x2 baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("crosstab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("2x2 with chi-squared row")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

local ++case_count
local scenario "crosstab_3x3_chi2"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Cross3x3"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    crosstab foreign rep78, xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: crosstab 3x3")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("crosstab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("3x3 with chi-squared row")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("crosstab 3x3 baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("crosstab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("3x3 with chi-squared row")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# diagtab
* =========================================================================

local ++case_count
local scenario "diagtab_basic"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Diag"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    webuse nhanes2, clear
    gen byte bmi_high = (bmi >= 30) if !missing(bmi)
    diagtab bmi_high diabetes, xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: diagtab")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("diagtab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Sensitivity and specificity table")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("diagtab baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("diagtab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Sensitivity and specificity table")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# effecttab
* =========================================================================

local ++case_count
local scenario "effecttab_single_model"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Single"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: effecttab single") ///
        effect("ATE") clean
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("effecttab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Single-model treatment effects")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("effecttab single baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("effecttab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Single-model treatment effects")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

local ++case_count
local scenario "effecttab_multi_model"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Multi"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ra (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: effecttab multi") ///
        effect("ATE") models("RA \ IPW") clean
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("effecttab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Multiple collected models")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("effecttab multi baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("effecttab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Multiple collected models")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

local ++case_count
local scenario "effecttab_from_matrix"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Matrix"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    clear
    matrix mymat = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001 \ -0.5, -1.2, 0.2, 0.15)
    matrix rownames mymat = Age Sex BMI
    effecttab, from(mymat) xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: effecttab matrix") effect("OR")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("effecttab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("From-matrix path")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("effecttab matrix baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("effecttab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("From-matrix path")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# regtab
* =========================================================================

local ++case_count
local scenario "regtab_single_model"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Single"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: regtab single")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("regtab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Single collected regression model")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("regtab single baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("regtab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Single collected regression model")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

local ++case_count
local scenario "regtab_compact_multi"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Compact"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: regtab compact") ///
        compact models("Model 1 \ Model 2")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("regtab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Compact multi-model regression table")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("regtab compact baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("regtab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Compact multi-model regression table")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# stratetab
* =========================================================================

quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 25, cond(_n == 2, 18, 32))
    gen _Y = cond(_n == 1, 5000, cond(_n == 2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_lbl
    save "`workbook_dir'/_rb_strate_o1e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 8, 20))
    gen _Y = cond(_n == 1, 5000, cond(_n == 2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_lbl
    save "`workbook_dir'/_rb_strate_o2e1.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n == 1, 8, cond(_n == 2, 14, cond(_n == 3, 22, 30)))
    gen _Y = cond(_n == 1, 800, cond(_n == 2, 1200, cond(_n == 3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
    label values duration_cat dur_lbl
    save "`workbook_dir'/_rb_strate_o1e2.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n == 1, 4, cond(_n == 2, 9, cond(_n == 3, 15, 20)))
    gen _Y = cond(_n == 1, 800, cond(_n == 2, 1200, cond(_n == 3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
    label values duration_cat dur_lbl
    save "`workbook_dir'/_rb_strate_o2e2.dta", replace
}

local ++case_count
local scenario "stratetab_multi_exposure"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Rates"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    clear
    stratetab, using("`workbook_dir'/_rb_strate_o1e1" "`workbook_dir'/_rb_strate_o2e1" ///
        "`workbook_dir'/_rb_strate_o1e2" "`workbook_dir'/_rb_strate_o2e2") ///
        outcomes(2) xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: stratetab") outlabels("Outcome 1 \ Outcome 2") ///
        explabels("Type 1 \ Type 2")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("stratetab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Two outcomes by two exposure types")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("stratetab baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("stratetab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Two outcomes by two exposure types")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# survtab
* =========================================================================

local ++case_count
local scenario "survtab_km"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "KM"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(5 10 15 20) by(drug) xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: survtab KM")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("survtab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Kaplan-Meier estimates by group")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("survtab KM baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("survtab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Kaplan-Meier estimates by group")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

local ++case_count
local scenario "survtab_median"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Median"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(5 10 15 20) by(drug) median xlsx("`xlsx'") sheet("`sheet'") ///
        title("Refactor Baseline: survtab median")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("survtab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Median survival table")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("survtab median baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("survtab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Median survival table")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# table1_tc
* =========================================================================

local ++case_count
local scenario "table1_tc_autodetect"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Auto"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto \ headroom auto) ///
        xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: table1 auto")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("table1_tc") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Grouped auto-detect baseline")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("table1 auto baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("table1_tc") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Grouped auto-detect baseline")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

local ++case_count
local scenario "table1_tc_forced_types"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Forced"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn %9.0f \ mpg contn %9.1f \ weight contn \ rep78 cat) ///
        xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: table1 forced")
    confirm file "`xlsx'"
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("table1_tc") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Grouped forced-type baseline")
    display as result "  PASS: `scenario'"
}
else {
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("table1 forced baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("table1_tc") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Grouped forced-type baseline")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

* =========================================================================
**# comptab
* =========================================================================

local ++case_count
local scenario "comptab_sections"
local xlsx "`workbook_dir'/`scenario'.xlsx"
local sheet "Comp"
local summary_file "`summary_dir'/`scenario'.tsv"
capture erase "`xlsx'"
capture erase "`summary_file'"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    regtab, frame(_rb_comp1, replace) noint
    collect clear
    collect: regress price i.rep78 mpg weight
    regtab, frame(_rb_comp2, replace) noint
    comptab _rb_comp1 _rb_comp2, rows(1 \ 1 2) ///
        section("Binary" \ "Categories") ///
        xlsx("`xlsx'") sheet("`sheet'") title("Refactor Baseline: comptab")
    confirm file "`xlsx'"
    capture frame drop _rb_comp1
    capture frame drop _rb_comp2
}
if _rc == 0 {
    local ++pass_count
    _rb_write_summary, xlsx("`xlsx'") sheet("`sheet'") outfile("`summary_file'") ///
        pycmd("`python_cmd'") tool("`summary_tool'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("comptab") ///
        status("PASS") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Two-frame composite with sections")
    display as result "  PASS: `scenario'"
}
else {
    capture frame drop _rb_comp1
    capture frame drop _rb_comp2
    local ++fail_count
    local failed_cases "`failed_cases' `scenario'"
    _rb_write_status, outfile("`summary_file'") status("FAIL") ///
        message("comptab baseline failed with rc=`=_rc'")
    _rb_post_case, postname(`posth') scenario("`scenario'") command("comptab") ///
        status("FAIL") xlsx("`xlsx'") sheet("`sheet'") ///
        summaryfile("`summary_file'") note("Two-frame composite with sections")
    display as error "  FAIL: `scenario' (rc=`=_rc')"
}

postclose `posth'

use `baseline_manifest_data', clear
order scenario command status xlsx sheet N_rows N_cols methods_present summary_file note
export delimited using "`manifest_file'", delimiter(tab) replace

display _newline as result "=== Refactor baseline: `pass_count' passed, `fail_count' failed out of `case_count' scenarios ==="
display as result "Manifest: `manifest_file'"
if `fail_count' > 0 {
    display as error "Failed scenarios:`failed_cases'"
    exit 1
}

log close _refactor_baseline
