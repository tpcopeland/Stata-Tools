* validation_stratetab.do - structure and return-value validation for stratetab
* Consolidated in v1.7.0 from: validation_output_quality.do, validation_tabtools.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _valstrate
log using "validation_stratetab.log", replace text name(_valstrate)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

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
tabtools set clear



* check_xlsx availability for Excel-content assertions in migrated sections
local has_check_xlsx = 0
capture confirm file "`checker'"
if _rc == 0 local has_check_xlsx = 1

**# Migrated: structure and content

* V4: stratetab Validation - Structure and Content
* ============================================================

* Create synthetic strate output files with KNOWN values
* Outcome 1: 3 exposure levels, known events and PY
clear
set obs 3
gen exposure = _n - 1
gen double _D = .
gen double _Y = .
gen double _Rate = .
gen double _Lower = .
gen double _Upper = .
label variable _Lower "Lower 95% confidence limit"
label variable _Upper "Upper 95% confidence limit"

replace _D = 25 in 1
replace _D = 18 in 2
replace _D = 32 in 3

replace _Y = 5000 in 1
replace _Y = 4500 in 2
replace _Y = 5200 in 3

replace _Rate = _D / _Y
replace _Lower = _Rate * 0.65
replace _Upper = _Rate * 1.35

label variable exposure "Treatment Group"
label define val_exp_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose"
label values exposure val_exp_lbl
capture erase "`output_dir'/_val_strate_o1e1.dta"
quietly save "`output_dir'/_val_strate_o1e1.dta"

* Outcome 2: same exposure structure
clear
set obs 3
gen exposure = _n - 1
gen double _D = .
gen double _Y = .
gen double _Rate = .
gen double _Lower = .
gen double _Upper = .
label variable _Lower "Lower 95% confidence limit"
label variable _Upper "Upper 95% confidence limit"

replace _D = 12 in 1
replace _D = 8 in 2
replace _D = 20 in 3

replace _Y = 5000 in 1
replace _Y = 4500 in 2
replace _Y = 5200 in 3

replace _Rate = _D / _Y
replace _Lower = _Rate * 0.65
replace _Upper = _Rate * 1.35

label define val_exp_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose", replace
label values exposure val_exp_lbl
capture erase "`output_dir'/_val_strate_o2e1.dta"
quietly save "`output_dir'/_val_strate_o2e1.dta"

* V4.1: Basic structure and formatting
capture noisily {
    capture erase "`output_dir'/_val_stratetab_basic.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_basic.xlsx") outcomes(2) ///
        sheet("Basic") title("Table. Incidence Rates") ///
        outlabels("Outcome A \ Outcome B")

    confirm file "`output_dir'/_val_stratetab_basic.xlsx"

    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_stratetab_basic.xlsx" ///
            --sheet Basic --min-rows 5 --min-cols 5 ///
            --has-borders ///
            --bold-row 1 --merged-row 1 ///
            --font Arial --fontsize 10 ///
            --cell-contains A1 "Table. Incidence Rates" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.1 - stratetab basic structure and formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.1 - stratetab structure (error `=_rc')"
    local ++fail_count
}

* V4.2: Outcome labels present in output
capture noisily {
    import excel "`output_dir'/_val_stratetab_basic.xlsx", sheet("Basic") clear
    local found_a = 0
    local found_b = 0
    foreach var of varlist * {
        forvalues i = 1/`=_N' {
            if strpos(`var'[`i'], "Outcome A") > 0 local found_a = 1
            if strpos(`var'[`i'], "Outcome B") > 0 local found_b = 1
        }
    }
    assert `found_a' == 1
    assert `found_b' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.2 - outcome labels present"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.2 - outcome labels (error `=_rc')"
    local ++fail_count
}

* V4.3: Rate patterns present
capture noisily {
    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_stratetab_basic.xlsx" ///
            --sheet Basic --min-rows 3 --min-cols 3 ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_stratetab_basic.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.3 - rate patterns in content"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.3 - rate patterns (error `=_rc')"
    local ++fail_count
}

* V4.4: Event counts are numeric and reasonable
capture noisily {
    import excel "`output_dir'/_val_stratetab_basic.xlsx", sheet("Basic") clear
    local found_events = 0
    forvalues i = 3/`=_N' {
        foreach var of varlist * {
            local val = `var'[`i']
            if regexm("`val'", "^[0-9]+$") {
                local numval = real("`val'")
                if `numval' >= 1 & `numval' <= 1000 {
                    local found_events = 1
                }
            }
        }
    }
    assert `found_events' == 1
}
if _rc == 0 {
    display as result "  PASS: V4.4 - event counts present and numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.4 - event counts (error `=_rc')"
    local ++fail_count
}

* V4.5: PY and rate scaling options
capture noisily {
    capture erase "`output_dir'/_val_stratetab_scale.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_scale.xlsx") outcomes(2) ///
        sheet("Scale") pyscale(1000) ratescale(1000)

    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_stratetab_scale.xlsx" ///
            --sheet Scale --min-rows 4 --min-cols 4 --has-borders ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_stratetab_scale.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.5 - PY and rate scaling"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.5 - scaling options (error `=_rc')"
    local ++fail_count
}

* V4.6: Custom decimal places
capture noisily {
    capture erase "`output_dir'/_val_stratetab_digits.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1" "`output_dir'/_val_strate_o2e1") ///
        xlsx("`output_dir'/_val_stratetab_digits.xlsx") outcomes(2) ///
        sheet("Digits") digits(2) eventdigits(0) pydigits(1)

    confirm file "`output_dir'/_val_stratetab_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: V4.6 - custom decimal places"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.6 - digits options (error `=_rc')"
    local ++fail_count
}

* V4.7: Single outcome
capture noisily {
    capture erase "`output_dir'/_val_stratetab_single.xlsx"
    stratetab, using("`output_dir'/_val_strate_o1e1") ///
        xlsx("`output_dir'/_val_stratetab_single.xlsx") outcomes(1) ///
        sheet("Single") title("Single Outcome Table")

    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_stratetab_single.xlsx" ///
            --sheet Single --min-rows 4 --min-cols 3 ///
            --cell-contains A1 "Single Outcome Table" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_stratetab_single.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V4.7 - single outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.7 - single outcome (error `=_rc')"
    local ++fail_count
}

* V4.8: Error - missing .xlsx extension
capture noisily {
    capture noisily stratetab, using("`output_dir'/_val_strate_o1e1") ///
        xlsx("`output_dir'/bad.csv") outcomes(1) sheet("T")
    local rc_val = _rc
    assert `rc_val' == 198
}
if _rc == 0 {
    display as result "  PASS: V4.8 - missing .xlsx extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.8 - .xlsx extension check (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: return value quality

**# SECTION 8: stratetab — validate return values
* ============================================================

* V18: stratetab rates matrix exact values
capture noisily {
    * Create synthetic strate data
    quietly {
        clear
        set obs 3
        gen exposure = _n - 1
        gen _D = cond(_n==1, 50, cond(_n==2, 30, 70))
        gen _Y = cond(_n==1, 10000, cond(_n==2, 8000, 12000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _val_exp 0 "Low" 1 "Med" 2 "High"
        label values exposure _val_exp
        save "`output_dir'/_val_strate_o1.dta", replace

        clear
        set obs 3
        gen exposure = cond(_n==1, 2, cond(_n==2, 1, 0))
        gen _D = cond(_n==1, 40, cond(_n==2, 15, 25))
        gen _Y = cond(_n==1, 12000, cond(_n==2, 8000, 10000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _val_exp 0 "Low" 1 "Med" 2 "High", replace
        label values exposure _val_exp
        save "`output_dir'/_val_strate_o2.dta", replace

        sysuse auto, clear
    }

    stratetab, using("`output_dir'/_val_strate_o1" "`output_dir'/_val_strate_o2") ///
        xlsx("`output_dir'/_val_stratetab.xlsx") outcomes(2)

    local row_low = rownumb(r(rates), "Low")
    local row_med = rownumb(r(rates), "Med")
    local row_high = rownumb(r(rates), "High")
    assert rowsof(r(rates)) == 3
    assert colsof(r(rates)) == 2
    assert `row_low' > 0
    assert `row_med' > 0
    assert `row_high' > 0
    assert abs(r(rates)[`row_low',1] - 5.0) < 1e-6
    assert abs(r(rates)[`row_low',2] - 2.5) < 1e-6
    assert abs(r(rates)[`row_med',1] - 3.75) < 1e-6
    assert abs(r(rates)[`row_med',2] - 1.875) < 1e-6
    assert abs(r(rates)[`row_high',1] - 70/12) < 1e-6
    assert abs(r(rates)[`row_high',2] - 10/3) < 1e-6
    local rate_cols : colnames r(rates)
    assert "`rate_cols'" == "Outcome_1 Outcome_2"
}
if _rc == 0 {
    display as result "  PASS: V18 stratetab rates matrix exact values"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 stratetab rates matrix exact values (error `=_rc')"
    local ++fail_count
}

* V19: stratetab rate values are correctly scaled
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_val_strate_o1" "`output_dir'/_val_strate_o2") ///
        xlsx("`output_dir'/_val_stratetab_scale.xlsx") outcomes(2)
    local row_low = rownumb(r(rates), "Low")
    assert `row_low' > 0
    assert abs(r(rates)[`row_low',1] - ((50/10000) * 1000)) < 1e-6
    assert abs(r(rates)[`row_low',2] - ((25/10000) * 1000)) < 1e-6
    assert abs(r(rates)[`row_low',1] - (50/10000)) > 1
}
if _rc == 0 {
    display as result "  PASS: V19 stratetab rate correctly scaled (5.0 per 1000)"
    local ++pass_count
}
else {
    display as error "  FAIL: V19 stratetab rate scaling (error `=_rc')"
    local ++fail_count
}

* V19b: stratetab aligns rate ratios by category label and exports matching CSV
capture noisily {
    quietly {
        clear
        set obs 3
        gen exposure = _n - 1
        gen _D = cond(_n==1, 250, cond(_n==2, 180, 320))
        gen _Y = cond(_n==1, 50000, cond(_n==2, 45000, 52000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _val_exp_rr 0 "Low" 1 "Med" 2 "High"
        label values exposure _val_exp_rr
        save "`output_dir'/_val_strate_rr_ref.dta", replace

        clear
        set obs 3
        gen exposure = cond(_n==1, 2, cond(_n==2, 1, 0))
        gen _D = cond(_n==1, 220, cond(_n==2, 140, 80))
        gen _Y = cond(_n==1, 20000, cond(_n==2, 12000, 8000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _val_exp_rr 0 "Low" 1 "Med" 2 "High", replace
        label values exposure _val_exp_rr
        save "`output_dir'/_val_strate_rr_exp.dta", replace

        sysuse auto, clear
    }

    local irr_low = (80/8000) / ((250/50000))
    local se_ln_low = sqrt(1/80 + 1/250)
    local irr_low_lo = exp(ln(`irr_low') - invnormal(0.975) * `se_ln_low')
    local irr_low_hi = exp(ln(`irr_low') + invnormal(0.975) * `se_ln_low')
    local irr_low_fmt = ///
        strtrim(string(round(`irr_low', 0.01), "%11.2f")) + ///
        " (" + strtrim(string(round(`irr_low_lo', 0.01), "%11.2f")) + ///
        "-" + strtrim(string(round(`irr_low_hi', 0.01), "%11.2f")) + ")"

    stratetab, using("`output_dir'/_val_strate_rr_ref" "`output_dir'/_val_strate_rr_exp") ///
        xlsx("`output_dir'/_val_stratetab_rr.xlsx") ///
        csv("`output_dir'/_val_stratetab_rr.csv") ///
        outcomes(1) rateratio sheet("aligned")

    assert "`r(xlsx)'" == "`output_dir'/_val_stratetab_rr.xlsx"
    assert "`r(sheet)'" == "aligned"
    assert rowsof(r(ratios)) == 3
    assert colsof(r(ratios)) == 1
    local row_high = rownumb(r(ratios), "High")
    local row_low = rownumb(r(ratios), "Low")
    local row_med = rownumb(r(ratios), "Med")
    assert `row_high' > 0
    assert `row_low' > 0
    assert `row_med' > 0
    assert abs(r(ratios)[`row_high',1] - ((220/20000) / ((320/52000)))) < 1e-6
    assert abs(r(ratios)[`row_low',1] - 2) < 1e-6
    assert abs(r(ratios)[`row_med',1] - ((140/12000) / ((180/45000)))) < 1e-6
    local ratio_cols : colnames r(ratios)
    assert "`ratio_cols'" == "Outcome_1"

    * CSV is written without Stata variable-name headers (v1.8.6 contract), so
    * import with varnames(nonames): label is column 1 (v1), IRR is column 5 (v5).
    preserve
    import delimited "`output_dir'/_val_stratetab_rr.csv", clear varnames(nonames)
    local _irr_found = 0
    forvalues _r = 1/`=_N' {
        local _lbl = strtrim(v1[`_r'])
        local _irr = strtrim(v5[`_r'])
        if "`_lbl'" == "Low" & "`_irr'" == "`irr_low_fmt'" {
            local _irr_found = 1
            continue, break
        }
    }
    assert `_irr_found' == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: V19b stratetab rateratio aligns labels and CSV values"
    local ++pass_count
}
else {
    display as error "  FAIL: V19b stratetab aligned rateratio/CSV (error `=_rc')"
    local ++fail_count
}

* V20: stratetab rate-ratio CI uses the exact normal quantile invnormal(0.975)
* Known-answer guard for the v1.9.4 fix (hardcoded 1.96 -> invnormal(0.975)).
* The IRR CI is emitted only in the formatted output cell, so we pin it through
* the CSV at ratiodigits(6): at six decimals the ~9e-6 gap between 1.96 and
* invnormal(0.975) is visible, so this test FAILS on the pre-1.9.4 code and
* PASSES only when stratetab uses the exact quantile.  Oracle is hand-computed
* from the event counts, independent of stratetab's own arithmetic path.
capture noisily {
    quietly {
        clear
        set obs 3
        gen exposure = _n - 1
        gen _D = cond(_n==1, 250, cond(_n==2, 180, 320))
        gen _Y = cond(_n==1, 50000, cond(_n==2, 45000, 52000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _val_exp_z 0 "Low" 1 "Med" 2 "High"
        label values exposure _val_exp_z
        save "`output_dir'/_val_strate_z_ref.dta", replace

        clear
        set obs 3
        gen exposure = cond(_n==1, 2, cond(_n==2, 1, 0))
        gen _D = cond(_n==1, 220, cond(_n==2, 140, 80))
        gen _Y = cond(_n==1, 20000, cond(_n==2, 12000, 8000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _val_exp_z 0 "Low" 1 "Med" 2 "High", replace
        label values exposure _val_exp_z
        save "`output_dir'/_val_strate_z_exp.dta", replace

        sysuse auto, clear
    }

    * Hand oracle for the "Low" category (exp D=80/Y=8000 vs ref D=250/Y=50000)
    local rd = 6
    local z  = invnormal(0.975)
    local irr    = (80/8000) / (250/50000)
    local se_ln  = sqrt(1/80 + 1/250)
    local irr_lo = exp(ln(`irr') - `z' * `se_ln')
    local irr_hi = exp(ln(`irr') + `z' * `se_ln')
    local irr_cell = ///
        strtrim(string(round(`irr',    10^(-`rd')), "%11.`rd'f")) + ///
        " (" + strtrim(string(round(`irr_lo', 10^(-`rd')), "%11.`rd'f")) + ///
        "-"  + strtrim(string(round(`irr_hi', 10^(-`rd')), "%11.`rd'f")) + ")"

    stratetab, using("`output_dir'/_val_strate_z_ref" "`output_dir'/_val_strate_z_exp") ///
        csv("`output_dir'/_val_stratetab_z.csv") ///
        outcomes(1) rateratio ratiodigits(`rd')

    * Point estimate returned exactly in r(ratios)
    local row_low = rownumb(r(ratios), "Low")
    assert `row_low' > 0
    assert abs(r(ratios)[`row_low',1] - 2) < 1e-9

    * CSV IRR cell (column 5) must equal the invnormal(0.975) oracle to 6 dp
    preserve
    import delimited "`output_dir'/_val_stratetab_z.csv", clear varnames(nonames)
    local _found = 0
    forvalues _r = 1/`=_N' {
        if strtrim(v1[`_r']) == "Low" & strtrim(v5[`_r']) == "`irr_cell'" local _found = 1
    }
    assert `_found' == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: V20 stratetab IRR CI uses invnormal(0.975) (6-dp oracle)"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 stratetab IRR CI invnormal(0.975) guard (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_stratetab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valstrate
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_stratetab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valstrate
