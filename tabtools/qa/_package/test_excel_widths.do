* test_excel_widths.do - Focused workbook width and merge regression checks
* Purpose: catch column-width regressions and unmerged summary rows in tabtools Excel output

capture log close _wx
log using "test_excel_widths.log", replace text name(_wx)

local n_pass = 0
local n_fail = 0
local n_total = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local checker "`qa_dir'/tools/check_xlsx.py"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_xlsx.py not available"
    log close _wx
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
    display as error "FAIL: python/openpyxl checker runtime not available"
    log close _wx
    exit 601
}

capture program drop _wx_assert
program define _wx_assert
    args result_file checks
    shell `checks'
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

* =========================================================================
**# WX1: regtab CI column width tracks rendered content
* =========================================================================
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 20260419
    gen double x = _n
    gen double z = runiform()
    gen double y = 123456789.123456 * x - 98765432.654321 * z + rnormal()*1000
    collect clear
    collect: regress y x z
    capture erase "`output_dir'/_wx_regtab.xlsx"
    regtab, xlsx("`output_dir'/_wx_regtab.xlsx") sheet("Test") ///
        title("Regression Results") digits(6) stats(n ll)

    _wx_assert "`output_dir'/_wx_regtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_regtab.xlsx" --sheet "Test" --col-width-fits-content D 4 --result-file "`output_dir'/_wx_regtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX1 - regtab CI column width fits rendered content"
    local ++n_pass
}
else {
    display as error "  FAIL: WX1 - regtab CI column width fits rendered content (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX1A: regtab short-value columns stay tight
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    capture erase "`output_dir'/_wx_regtab_tight.xlsx"
    regtab, xlsx("`output_dir'/_wx_regtab_tight.xlsx") sheet("Short") ///
        title("Short Regression") coef("OR") noint

    _wx_assert "`output_dir'/_wx_regtab_tight.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_regtab_tight.xlsx" --sheet "Short" --col-width-at-most C 8 --col-width-at-most D 13 --col-width-at-most E 8 --result-file "`output_dir'/_wx_regtab_tight.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX1A - regtab short-value columns stay tight"
    local ++n_pass
}
else {
    display as error "  FAIL: WX1A - regtab short-value columns stay tight (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX2: effecttab CI column width
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_wx_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_wx_effecttab.xlsx") sheet("Effects") ///
        title("Treatment Effects")

    _wx_assert "`output_dir'/_wx_effecttab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_effecttab.xlsx" --sheet "Effects" --col-width-at-least D 18 --result-file "`output_dir'/_wx_effecttab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX2 - effecttab CI column width"
    local ++n_pass
}
else {
    display as error "  FAIL: WX2 - effecttab CI column width (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX3: comptab CI column width
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, frame(_wx_m1, replace) noint
    collect clear
    collect: regress price mpg weight length
    regtab, frame(_wx_m2, replace) noint
    capture erase "`output_dir'/_wx_comptab.xlsx"
    comptab _wx_m1 _wx_m2, rows(1/2 \ 1/3) ///
        xlsx("`output_dir'/_wx_comptab.xlsx") sheet("Comp") title("Composite")
    capture frame drop _wx_m1
    capture frame drop _wx_m2

    _wx_assert "`output_dir'/_wx_comptab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_comptab.xlsx" --sheet "Comp" --col-width-at-least D 17 --result-file "`output_dir'/_wx_comptab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX3 - comptab CI column width"
    local ++n_pass
}
else {
    display as error "  FAIL: WX3 - comptab CI column width (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX4: corrtab long-label headers expand all data columns
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    label variable price "Vehicle price in USD"
    label variable mpg "Fuel economy miles per gallon"
    label variable weight "Vehicle curb weight"
    label variable length "Vehicle length inches"
    capture erase "`output_dir'/_wx_corrtab.xlsx"
    corrtab price mpg weight length, xlsx("`output_dir'/_wx_corrtab.xlsx") ///
        sheet("Corr") title("Correlation Matrix")

    _wx_assert "`output_dir'/_wx_corrtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_corrtab.xlsx" --sheet "Corr" --col-width-at-least C 24 --col-width-at-least D 24 --col-width-at-least E 24 --col-width-at-least F 24 --result-file "`output_dir'/_wx_corrtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX4 - corrtab long-label widths"
    local ++n_pass
}
else {
    display as error "  FAIL: WX4 - corrtab long-label widths (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX5: table1_tc data columns widen for longer summaries
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_wx_table1.xlsx"
    table1_tc, by(foreign) vars(price contn %9.0f \ mpg contn %9.1f \ weight contn \ rep78 cat) ///
        excel("`output_dir'/_wx_table1.xlsx") title("Baseline Characteristics")

    _wx_assert "`output_dir'/_wx_table1.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_table1.xlsx" --sheet "Table 1" --col-width-at-least C 17 --col-width-at-least D 17 --result-file "`output_dir'/_wx_table1.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX5 - table1_tc data-column widths"
    local ++n_pass
}
else {
    display as error "  FAIL: WX5 - table1_tc data-column widths (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX6: crosstab summary row is merged
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = mpg > 20
    capture erase "`output_dir'/_wx_crosstab.xlsx"
    crosstab highmpg foreign, xlsx("`output_dir'/_wx_crosstab.xlsx") sheet("Cross")

    _wx_assert "`output_dir'/_wx_crosstab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_crosstab.xlsx" --sheet "Cross" --merged-row 6 --result-file "`output_dir'/_wx_crosstab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX6 - crosstab summary row merged"
    local ++n_pass
}
else {
    display as error "  FAIL: WX6 - crosstab summary row merged (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX7: survtab log-rank row is merged
* =========================================================================
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture erase "`output_dir'/_wx_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("`output_dir'/_wx_survtab.xlsx") ///
        sheet("Surv") title("Survival Estimates") events

    _wx_assert "`output_dir'/_wx_survtab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_survtab.xlsx" --sheet "Surv" --merged-row 10 --result-file "`output_dir'/_wx_survtab.txt" --quiet"'
}
if _rc == 0 {
    display as result "  PASS: WX7 - survtab log-rank row merged"
    local ++n_pass
}
else {
    display as error "  FAIL: WX7 - survtab log-rank row merged (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# WX8: hrcomptab keeps events/exposure/p-value columns tight
* =========================================================================
local ++n_total
capture noisily {
    capture frame drop _wx_hr_rates
    capture frame drop _wx_hr_bin
    capture frame drop _wx_hr_dose

    tempfile _wx_rate1 _wx_rate2

    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 42, 31)
    gen double _Y = cond(_n == 1, 5200, 4980)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.75
    gen double _Upper = _Rate * 1.25
    label define _wx_exp2 0 "No HRT" 1 "Any HRT", replace
    label values exposure _wx_exp2
    save "`_wx_rate1'.dta", replace

    clear
    set obs 4
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 42, cond(_n == 2, 16, cond(_n == 3, 9, 6)))
    gen double _Y = cond(_n == 1, 5200, cond(_n == 2, 1760, cond(_n == 3, 1510, 1710)))
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.70
    gen double _Upper = _Rate * 1.30
    label define _wx_exp4 0 "No HRT" 1 "Low dose" 2 "Medium dose" 3 "High dose", replace
    label values exposure _wx_exp4
    save "`_wx_rate2'.dta", replace

    clear
    stratetab, using(`_wx_rate1' `_wx_rate2') outcomes(1) ///
        frame(_wx_hr_rates, replace) ///
        outlabels("Sustained EDSS 4") ///
        explabels("Any HRT" \ "Estrogen Dose")

    clear
    set obs 30
    set seed 20260418
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    regtab, frame(_wx_hr_bin, replace) noint

    clear
    set obs 45
    gen byte dose = mod(_n, 4)
    gen double y = 12 + 1.5 * (dose == 1) + 2.5 * (dose == 2) + 3.5 * (dose == 3) + rnormal()
    collect clear
    collect: regress y i.dose
    regtab, frame(_wx_hr_dose, replace) noint

    capture erase "`output_dir'/_wx_hrcomptab.xlsx"
    hrcomptab _wx_hr_rates, modelframes(_wx_hr_bin _wx_hr_dose) ///
        rownames("treated" \ "1 2 3") ///
        xlsx("`output_dir'/_wx_hrcomptab.xlsx") sheet("HRComp") ///
        title("HR Composite") effect("aHR")

    _wx_assert "`output_dir'/_wx_hrcomptab.txt" ///
        `"`python_cmd' "`checker'" "`output_dir'/_wx_hrcomptab.xlsx" --sheet "HRComp" --col-width-at-most B 15 --col-width-at-most C 8 --col-width-at-least D 15 --col-width-at-least E 17 --col-width-at-least F 14 --col-width-at-most G 8 --result-file "`output_dir'/_wx_hrcomptab.txt" --quiet"'

    capture frame drop _wx_hr_rates
    capture frame drop _wx_hr_bin
    capture frame drop _wx_hr_dose
}
if _rc == 0 {
    display as result "  PASS: WX8 - hrcomptab column widths"
    local ++n_pass
}
else {
    display as error "  FAIL: WX8 - hrcomptab column widths (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _wx_hr_rates
capture frame drop _wx_hr_bin
capture frame drop _wx_hr_dose

display _newline as result "Excel Width Tests Complete"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}

foreach f in _wx_regtab.txt _wx_regtab_tight.txt _wx_effecttab.txt _wx_comptab.txt _wx_corrtab.txt _wx_table1.txt _wx_crosstab.txt _wx_survtab.txt _wx_hrcomptab.txt {
    capture erase "`output_dir'/`f'"
}

assert `n_fail' == 0

log close _wx
