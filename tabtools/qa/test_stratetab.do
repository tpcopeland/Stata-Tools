* test_stratetab.do - complete QA for stratetab
* Consolidated in v1.7.0 from: test_stratetab.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _stratetab
log using "test_stratetab.log", replace text name(_stratetab)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
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


**# Test helpers migrated from review_* contract files
capture program drop _review_strate_file
program define _review_strate_file
    syntax , BASENAME(string) [MODE(string)]
    clear
    set obs 2
    gen str20 category = cond(_n == 1, "Low", "High")
    if "`mode'" == "duplicate" replace category = "Low"
    if "`mode'" == "blank" replace category = "" in 2
    if "`mode'" == "mismatch" replace category = cond(_n == 1, "Low", "Medium")
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 2000)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2
    save "`basename'.dta", replace
end


**# Migrated from test_stratetab.do


**# Helpers
program define _make_issue_strate
    syntax , BASENAME(string)
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp 0 "Low" 1 "Medium" 2 "High", replace
    label values exposure issue_exp
    save "`basename'.dta", replace
end

**## early failure restores varabbrev and preserves the original return code
capture noisily {
    tempfile missing_rate
    * Guarantee the precondition: the using file must NOT exist. A bare tempfile
    * name is not enough — in a long session (e.g. run_all) an earlier do-file's
    * first tempfile shares this session-rooted name, and any `save "<tf>.dta"'
    * leaves a leftover .dta that Stata does not auto-erase (it only tracks the
    * bare tempname). Erase it so stratetab reliably hits the file-not-found path.
    capture erase "`missing_rate'.dta"
    local _orig_varabbrev = c(varabbrev)
    set varabbrev on
    capture stratetab, using("`missing_rate'") outcomes(1) display
    local got_rc = _rc
    local final_varabbrev "`c(varabbrev)'"
    set varabbrev `_orig_varabbrev'
    assert `got_rc' == 601
    assert "`final_varabbrev'" == "on"
}
if _rc == 0 {
    display as result "  PASS: stratetab early failures restore varabbrev and return 601"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab early failure cleanup regression (rc=`=_rc')"
    local ++fail_count
}

**# Output Modes
**## console-only mode works without xlsx() or a preloaded dataset
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    clear
    stratetab, using("`rate1'") outcomes(1) display
    assert r(N_rows) >= 6
    assert _N == 0
    assert c(k) == 0
}
if _rc == 0 {
    display as result "  PASS: stratetab display without xlsx() from empty workspace"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display without xlsx() from empty workspace (rc=`=_rc')"
    local ++fail_count
}

**## frame() works without xlsx()
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    clear
    capture frame drop issue_rates
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates, replace)
    assert "`r(frame)'" == "issue_rates"
    frame issue_rates: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop issue_rates

**## display + frame() work together without xlsx()
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    clear
    capture frame drop issue_rates2
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates2, replace) display
    assert "`r(frame)'" == "issue_rates2"
    frame issue_rates2: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab display + frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display + frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop issue_rates2

**## xlsx export still works alongside frame()
capture noisily {
    tempfile rate1
    _make_issue_strate, basename("`rate1'")
    local xlsx "`output_dir'/stratetab_issue.xlsx"
    capture erase "`xlsx'"
    clear
    capture frame drop issue_rates3
    stratetab, using("`rate1'") outcomes(1) xlsx("`xlsx'") sheet("Rates") ///
        title("Issue Rates") frame(issue_rates3, replace) display
    confirm file "`xlsx'"
    assert "`r(frame)'" == "issue_rates3"
    frame issue_rates3: assert _N >= 6
}
if _rc == 0 {
    display as result "  PASS: stratetab xlsx + frame() + display"
    local ++pass_count
}
	else {
	    display as error "  FAIL: stratetab xlsx + frame() + display (rc=`=_rc')"
	    local ++fail_count
	}
	capture frame drop issue_rates3

**## multi-outcome xlsx path does not emit brace parser noise
capture noisily {
    tempfile rate11 rate12 rate21 rate22 brace_log
    local xlsx "`output_dir'/stratetab_brace_check.xlsx"
    capture erase "`xlsx'"
    _make_issue_strate, basename("`rate11'")
    _make_issue_strate, basename("`rate12'")
    _make_issue_strate, basename("`rate21'")
    _make_issue_strate, basename("`rate22'")
    clear
    capture log close _bracechk
    log using "`brace_log'", replace text name(_bracechk)
    stratetab, using("`rate11'" "`rate12'" "`rate21'" "`rate22'") ///
        outcomes(2) xlsx("`xlsx'") sheet("Rates") ///
        outlabels("Outcome A \ Outcome B") ///
        explabels("Exposure A \ Exposure B") ///
        rateratio footnote("IRR = incidence rate ratio.")
    log close _bracechk
    confirm file "`xlsx'"
    tempname fh
    local saw_brace = 0
    file open `fh' using "`brace_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(lower(`"`line'"'), "matching close brace not found") > 0 {
            local saw_brace = 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `saw_brace' == 0
}
if _rc == 0 {
    display as result "  PASS: stratetab xlsx path avoids brace parser noise"
    local ++pass_count
}
else {
    capture log close _bracechk
    display as error "  FAIL: stratetab brace parser regression (rc=`=_rc')"
    local ++fail_count
}

	**## malformed color options fail before workbook creation
	capture noisily {
	    tempfile rate1
	    _make_issue_strate, basename("`rate1'")
	    local bad_header "`output_dir'/stratetab_bad_headercolor.xlsx"
	    local bad_zebra "`output_dir'/stratetab_bad_zebracolor.xlsx"
	    capture erase "`bad_header'"
	    capture erase "`bad_zebra'"
	    clear
	    capture stratetab, using("`rate1'") outcomes(1) xlsx("`bad_header'") ///
	        headershade headercolor("1 2")
	    assert _rc == 198
	    capture confirm file "`bad_header'"
	    assert _rc == 601
	
	    capture stratetab, using("`rate1'") outcomes(1) xlsx("`bad_zebra'") ///
	        zebra zebracolor("999 0 0")
	    assert _rc == 198
	    capture confirm file "`bad_zebra'"
	    assert _rc == 601
	}
	if _rc == 0 {
	    display as result "  PASS: stratetab rejects malformed headercolor()/zebracolor() early"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: stratetab malformed color validation (rc=`=_rc')"
	    local ++fail_count
	}

	**## r(rates) is still returned above 200 category rows
	capture noisily {
	    tempfile many1
	    clear
	    set obs 201
	    gen str8 category = "Cat" + string(_n, "%03.0f")
	    gen double _D = _n
	    gen double _Y = 1000 + _n
	    gen double _Rate = _D / _Y
	    gen double _Lower = _Rate * 0.8
	    gen double _Upper = _Rate * 1.2
	    save "`many1'.dta", replace
	
	    clear
	    stratetab, using("`many1'") outcomes(1) display
	    confirm matrix r(rates)
	    assert rowsof(r(rates)) == 201
	    assert colsof(r(rates)) == 1
	}
	if _rc == 0 {
	    display as result "  PASS: stratetab returns r(rates) above 200 rows"
	    local ++pass_count
	}
	else {
	    display as error "  FAIL: stratetab matrix return above 200 rows (rc=`=_rc')"
	    local ++fail_count
	}

	**## multi-exposure r(rates) rownames remain exposure-specific
	capture noisily {
	    tempfile rate1 rate2
	    _make_issue_strate, basename("`rate1'")
	    _make_issue_strate, basename("`rate2'")
	    clear
	    stratetab, using("`rate1'" "`rate2'") outcomes(1) display
	    assert rownumb(r(rates), "e1_Low") > 0
	    assert rownumb(r(rates), "e2_Low") > 0
	    assert rownumb(r(rates), "e1_High") > 0
	    assert rownumb(r(rates), "e2_High") > 0
	}
	if _rc == 0 {
	    display as result "  PASS: stratetab multi-exposure rownames are explicit"
	    local ++pass_count
	}
		else {
		    display as error "  FAIL: stratetab multi-exposure rownames (rc=`=_rc')"
		    local ++fail_count
		}

		**## truncated r(rates) and r(ratios) rownames remain unique
		capture noisily {
		    tempfile long1 long2
		    clear
		    set obs 2
		    gen str80 category = cond(_n == 1, ///
		        "Alpha beta gamma delta epsilon zeta first", ///
		        "Alpha beta gamma delta epsilon zeta second")
		    gen double _D = cond(_n == 1, 100, 80)
		    gen double _Y = 1000
		    gen double _Rate = _D / _Y
		    gen double _Lower = _Rate * 0.8
		    gen double _Upper = _Rate * 1.2
		    save "`long1'.dta", replace

		    replace _D = cond(_n == 1, 75, 60)
		    replace _Rate = _D / _Y
		    replace _Lower = _Rate * 0.8
		    replace _Upper = _Rate * 1.2
		    save "`long2'.dta", replace

		    clear
		    stratetab, using("`long1'" "`long2'") outcomes(1) rateratio display

		    local rate_names : rownames r(rates)
		    local n_rate_names : word count `rate_names'
		    assert `n_rate_names' == 4
		    forvalues i = 1/`n_rate_names' {
		        local rate_i : word `i' of `rate_names'
		        assert strlen("`rate_i'") <= 32
		        if `i' < `n_rate_names' {
		            forvalues j = `=`i' + 1'/`n_rate_names' {
		                local rate_j : word `j' of `rate_names'
		                assert "`rate_i'" != "`rate_j'"
		            }
		        }
		    }

		    local ratio_names : rownames r(ratios)
		    local n_ratio_names : word count `ratio_names'
		    assert `n_ratio_names' == 2
		    forvalues i = 1/`n_ratio_names' {
		        local ratio_i : word `i' of `ratio_names'
		        assert strlen("`ratio_i'") <= 32
		        if `i' < `n_ratio_names' {
		            forvalues j = `=`i' + 1'/`n_ratio_names' {
		                local ratio_j : word `j' of `ratio_names'
		                assert "`ratio_i'" != "`ratio_j'"
		            }
		        }
		    }
		}
		if _rc == 0 {
		    display as result "  PASS: stratetab suffixes truncated matrix rownames"
		    local ++pass_count
		}
		else {
		    display as error "  FAIL: stratetab truncated matrix rownames (rc=`=_rc')"
		    local ++fail_count
		}

**# Migrated from test_stratetab_order.do
* Regression: stratetab must preserve the original row order from strate
* output files. Bug: bysort in the duplicate-label check re-sorted rows
* alphabetically. Categories deliberately NOT alphabetical: Zebra, Apple,
* Mango — if stratetab re-sorts, output order becomes Apple, Mango, Zebra.
capture noisily {
    clear
    input str10 category _D _Y _Rate _Lower _Upper
    "Zebra"   50 1000  50  37  66
    "Apple"   30  800  37  26  53
    "Mango"   20  500  40  25  62
    end
    save "`output_dir'/strate_order_test_o1_e1.dta", replace

    clear
    input str10 category _D _Y _Rate _Lower _Upper
    "Zebra"   15 1000  15  9  25
    "Apple"   10  800  12  6  23
    "Mango"    8  500  16  8  31
    end
    save "`output_dir'/strate_order_test_o2_e1.dta", replace

    clear
    stratetab, using("`output_dir'/strate_order_test_o1_e1" "`output_dir'/strate_order_test_o2_e1") ///
        xlsx("`output_dir'/strate_order_test.xlsx") outcomes(2) ///
        outlabels(Outcome A \ Outcome B) ///
        explabels(Test Exposure)

    * Row 1 should be Zebra (rate=50000 after *1000 default), not Apple
    local row1_rate = r(rates)[1,1]
    local row2_rate = r(rates)[2,1]
    local row3_rate = r(rates)[3,1]
    assert abs(`row1_rate' - 50000) < 1
    assert abs(`row2_rate' - 37000) < 1
    assert abs(`row3_rate' - 40000) < 1
}
if _rc == 0 {
    display as result "  PASS: stratetab preserves original strate row order"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab strate row order regression (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/strate_order_test_o1_e1.dta"
capture erase "`output_dir'/strate_order_test_o2_e1.dta"
capture erase "`output_dir'/strate_order_test.xlsx"
**# Migrated: legacy suite: stratetab section

* ============================================================
* stratetab Tests
* ============================================================

* Create synthetic strate output files
quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 25, cond(_n==2, 18, 32))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current"
    label values exposure exp_lbl
    save "`output_dir'/_strate_o1e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 12, cond(_n==2, 8, 20))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_lbl
    save "`output_dir'/_strate_o2e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 15, cond(_n==2, 22, 28))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_lbl 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_lbl
    save "`output_dir'/_strate_o3e1.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n==1, 8, cond(_n==2, 14, cond(_n==3, 22, 30)))
    gen _Y = cond(_n==1, 800, cond(_n==2, 1200, cond(_n==3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years"
    label values duration_cat dur_lbl
    save "`output_dir'/_strate_o1e2.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n==1, 4, cond(_n==2, 9, cond(_n==3, 15, 20)))
    gen _Y = cond(_n==1, 800, cond(_n==2, 1200, cond(_n==3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
    label values duration_cat dur_lbl
    save "`output_dir'/_strate_o2e2.dta", replace

    clear
    set obs 4
    gen duration_cat = _n
    gen _D = cond(_n==1, 12, cond(_n==2, 18, cond(_n==3, 25, 35)))
    gen _Y = cond(_n==1, 800, cond(_n==2, 1200, cond(_n==3, 2000, 3000)))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define dur_lbl 1 "Never" 2 "<1 year" 3 "1-5 years" 4 ">5 years", replace
    label values duration_cat dur_lbl
    save "`output_dir'/_strate_o3e2.dta", replace
}

* Test: Basic stratetab (single exposure)
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab.xlsx") outcomes(3)
    confirm file "`output_dir'/_test_stratetab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - basic single exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - basic single exposure (error `=_rc')"
    local ++fail_count
}

* Test: Custom outcome labels
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_lab.xlsx") outcomes(3) ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse")
    confirm file "`output_dir'/_test_stratetab_lab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - outlabels"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - outlabels (error `=_rc')"
    local ++fail_count
}

* Test: Custom exposure labels
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_exp.xlsx") outcomes(3) ///
        explabels("Time-Varying HRT")
    confirm file "`output_dir'/_test_stratetab_exp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - explabels"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - explabels (error `=_rc')"
    local ++fail_count
}

* Test: Multiple exposure types
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1" "`output_dir'/_strate_o1e2" "`output_dir'/_strate_o2e2" "`output_dir'/_strate_o3e2") ///
        xlsx("`output_dir'/_test_stratetab_multi.xlsx") outcomes(3) ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse") explabels("Time-Varying \ Duration")
    confirm file "`output_dir'/_test_stratetab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - multiple exposure types"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - multiple exposure types (error `=_rc')"
    local ++fail_count
}

* Test: Custom sheet name
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_sh.xlsx") outcomes(3) sheet("Table 2")
    confirm file "`output_dir'/_test_stratetab_sh.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - custom sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - custom sheet (error `=_rc')"
    local ++fail_count
}

* Test: Title option
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_title.xlsx") outcomes(3) ///
        title("Table 2. Unadjusted incidence rates")
    confirm file "`output_dir'/_test_stratetab_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - title"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - title (error `=_rc')"
    local ++fail_count
}

* Test: Custom digits
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_dig.xlsx") outcomes(3) digits(2)
    confirm file "`output_dir'/_test_stratetab_dig.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - custom digits"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - custom digits (error `=_rc')"
    local ++fail_count
}

* Test: Event digits and PY digits
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_evtpy.xlsx") outcomes(3) ///
        eventdigits(1) pydigits(1)
    confirm file "`output_dir'/_test_stratetab_evtpy.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - eventdigits/pydigits"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - eventdigits/pydigits (error `=_rc')"
    local ++fail_count
}

* Test: Rate scale and unit label
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_scale.xlsx") outcomes(3) ///
        ratescale(100) unitlabel("100")
    confirm file "`output_dir'/_test_stratetab_scale.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - ratescale/unitlabel"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - ratescale/unitlabel (error `=_rc')"
    local ++fail_count
}

* Test: PY scale
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1") ///
        xlsx("`output_dir'/_test_stratetab_pys.xlsx") outcomes(3) pyscale(1000)
    confirm file "`output_dir'/_test_stratetab_pys.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - pyscale"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - pyscale (error `=_rc')"
    local ++fail_count
}

* Test: Full options combination
capture noisily {
    stratetab, using("`output_dir'/_strate_o1e1" "`output_dir'/_strate_o2e1" "`output_dir'/_strate_o3e1" "`output_dir'/_strate_o1e2" "`output_dir'/_strate_o2e2" "`output_dir'/_strate_o3e2") ///
        xlsx("`output_dir'/_test_stratetab_full.xlsx") outcomes(3) ///
        sheet("Table 2") title("Table 2. Rates by Exposure") ///
        outlabels("EDSS 4 \ EDSS 6 \ Relapse") explabels("TV \ Duration") ///
        digits(2) eventdigits(0) pydigits(0)
    confirm file "`output_dir'/_test_stratetab_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab - full options"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab - full options (error `=_rc')"
    local ++fail_count
}


**# Migrated: v1.5 theme support

**# F7: stratetab theme() support
* =========================================================================

* --- F7.1: stratetab accepts theme(lancet) ---
* Note: stratetab requires strate output files; test syntax acceptance only
local ++n_total
capture noisily {
    sysuse auto, clear
    * Create a minimal strate-like output file for testing
    preserve
    clear
    set obs 3
    gen str30 _Category = ""
    replace _Category = "Total" in 1
    replace _Category = "Domestic" in 2
    replace _Category = "Foreign" in 3
    gen _D = .
    replace _D = 10 in 1
    replace _D = 6 in 2
    replace _D = 4 in 3
    gen _Y = .
    replace _Y = 100 in 1
    replace _Y = 60 in 2
    replace _Y = 40 in 3
    gen _Rate = .
    replace _Rate = 100 in 1
    replace _Rate = 100 in 2
    replace _Rate = 100 in 3
    gen _Lower = .
    replace _Lower = 50 in 1
    replace _Lower = 40 in 2
    replace _Lower = 30 in 3
    gen _Upper = .
    replace _Upper = 200 in 1
    replace _Upper = 180 in 2
    replace _Upper = 250 in 3
    save "output/_strate_test", replace
    restore
    stratetab, using("output/_strate_test") xlsx("output/test_f7_theme.xlsx") ///
        outcomes(1) title("Theme Test") theme(lancet)
}
if _rc == 0 {
    display as result "  PASS: F7.1 — stratetab theme(lancet) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: F7.1 — stratetab theme failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: comprehensive option coverage

**# SECTION 4: stratetab — comprehensive option coverage
* ============================================================

* Create strate output files for testing
quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 250, cond(_n==2, 180, 320))
    gen _Y = cond(_n==1, 50000, cond(_n==2, 45000, 52000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current"
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o1e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 120, cond(_n==2, 80, 200))
    gen _Y = cond(_n==1, 50000, cond(_n==2, 45000, 52000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o2e1.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 220, cond(_n==2, 140, 80))
    gen _Y = cond(_n==1, 20000, cond(_n==2, 12000, 8000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o1e2.dta", replace

    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 40, cond(_n==2, 90, 150))
    gen _Y = cond(_n==1, 8000, cond(_n==2, 12000, 20000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o2e2.dta", replace

    clear
    set obs 3
    gen exposure = cond(_n==1, 2, cond(_n==2, 1, 0))
    gen _D = cond(_n==1, 80, cond(_n==2, 140, 220))
    gen _Y = cond(_n==1, 8000, cond(_n==2, 12000, 20000))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define exp_cov 0 "Never" 1 "Former" 2 "Current", replace
    label values exposure exp_cov
    save "`output_dir'/_cov_strate_o1e2_rev.dta", replace

    * Reload some data to have in memory for stratetab (it saves/restores)
    sysuse auto, clear
}

* Test: title option
capture noisily {
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_title.xlsx") outcomes(2) ///
        title("Incidence Rates by Exposure Status")
    confirm file "`output_dir'/_cov_strate_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab title()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab title() (error `=_rc')"
    local ++fail_count
}

* Test: outlabels option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_outlabels.xlsx") outcomes(2) ///
        outlabels("Stroke \ Myocardial Infarction")
    confirm file "`output_dir'/_cov_strate_outlabels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab outlabels()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab outlabels() (error `=_rc')"
    local ++fail_count
}

* Test: explabels option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_explabels.xlsx") outcomes(2) ///
        explabels("Smoking Status")
    confirm file "`output_dir'/_cov_strate_explabels.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab explabels()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab explabels() (error `=_rc')"
    local ++fail_count
}

* Test: digits option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_digits.xlsx") outcomes(2) digits(3)
    confirm file "`output_dir'/_cov_strate_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab digits() (error `=_rc')"
    local ++fail_count
}

* Test: eventdigits option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_evdigits.xlsx") outcomes(2) eventdigits(1)
    confirm file "`output_dir'/_cov_strate_evdigits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab eventdigits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab eventdigits() (error `=_rc')"
    local ++fail_count
}

* Test: pydigits option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_pydigits.xlsx") outcomes(2) pydigits(2)
    confirm file "`output_dir'/_cov_strate_pydigits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab pydigits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab pydigits() (error `=_rc')"
    local ++fail_count
}

* Test: unitlabel option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_unitlabel.xlsx") outcomes(2) ///
        unitlabel("100,000") ratescale(100000)
    confirm file "`output_dir'/_cov_strate_unitlabel.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab unitlabel()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab unitlabel() (error `=_rc')"
    local ++fail_count
}

* Test: pyscale option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_pyscale.xlsx") outcomes(2) pyscale(365.25)
    confirm file "`output_dir'/_cov_strate_pyscale.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab pyscale()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab pyscale() (error `=_rc')"
    local ++fail_count
}

* Test: rateratio option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_rateratio.xlsx") outcomes(2) rateratio
    confirm file "`output_dir'/_cov_strate_rateratio.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab rateratio"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab rateratio (error `=_rc')"
    local ++fail_count
}

* Test: ratiodigits option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_ratiodigits.xlsx") outcomes(2) ///
        rateratio ratiodigits(3)
    confirm file "`output_dir'/_cov_strate_ratiodigits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab ratiodigits()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab ratiodigits() (error `=_rc')"
    local ++fail_count
}

* Test: rateratio handles reordered categories across exposures
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
        label define exp_cov_rr 0 "Never" 1 "Former" 2 "Current"
        label values exposure exp_cov_rr
        save "`output_dir'/_cov_strate_rr_ref.dta", replace

        clear
        set obs 3
        gen exposure = cond(_n==1, 2, cond(_n==2, 1, 0))
        gen _D = cond(_n==1, 220, cond(_n==2, 140, 80))
        gen _Y = cond(_n==1, 20000, cond(_n==2, 12000, 8000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label define exp_cov_rr 0 "Never" 1 "Former" 2 "Current", replace
        label values exposure exp_cov_rr
        save "`output_dir'/_cov_strate_rr_rev.dta", replace

        sysuse auto, clear
    }

    stratetab, using("`output_dir'/_cov_strate_rr_ref" "`output_dir'/_cov_strate_rr_rev") ///
        xlsx("`output_dir'/_cov_strate_rateratio_reordered.xlsx") outcomes(1) rateratio
    assert rowsof(r(ratios)) == 3
    local row_current = rownumb(r(ratios), "Current")
    local row_never = rownumb(r(ratios), "Never")
    local row_former = rownumb(r(ratios), "Former")
    assert `row_current' > 0
    assert `row_never' > 0
    assert `row_former' > 0
    assert abs(r(ratios)[`row_current',1] - ((220/20000) / (320/52000))) < 1e-6
    assert abs(r(ratios)[`row_former',1] - ((140/12000) / (180/45000))) < 1e-6
    assert abs(r(ratios)[`row_never',1] - 2) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: stratetab rateratio aligns reordered categories by label"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab reordered-category rateratio (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_footnote.xlsx") outcomes(2) ///
        footnote("Age-standardized rates per 1,000 person-years")
    confirm file "`output_dir'/_cov_strate_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_zebra.xlsx") outcomes(2) zebra
    confirm file "`output_dir'/_cov_strate_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab zebra (error `=_rc')"
    local ++fail_count
}

* Test: borderstyle option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_border.xlsx") outcomes(2) borderstyle(academic)
    confirm file "`output_dir'/_cov_strate_border.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab borderstyle(academic)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab borderstyle(academic) (error `=_rc')"
    local ++fail_count
}

* Test: theme option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_theme.xlsx") outcomes(2) theme(lancet)
    confirm file "`output_dir'/_cov_strate_theme.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: headershade option
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_headershade.xlsx") outcomes(2) headershade
    confirm file "`output_dir'/_cov_strate_headershade.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab headershade"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab headershade (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_colors.xlsx") outcomes(2) ///
        zebra headercolor("200 220 240") zebracolor("245 245 255")
    confirm file "`output_dir'/_cov_strate_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_csv.xlsx") outcomes(2) ///
        csv("`output_dir'/_cov_strate.csv")
    confirm file "`output_dir'/_cov_strate.csv"
}
if _rc == 0 {
    display as result "  PASS: stratetab csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab csv() (error `=_rc')"
    local ++fail_count
}

* Test: combined comprehensive stratetab
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_stress.xlsx") outcomes(2) ///
        title("Age-Standardized Incidence Rates") ///
        outlabels("Stroke \ MI") explabels("Smoking \ Alcohol") ///
        digits(2) eventdigits(0) pydigits(1) unitlabel("100,000") ///
        ratescale(100000) pyscale(365.25) rateratio ratiodigits(2) ///
        footnote("Rates per 100,000 person-years") ///
        zebra borderstyle(academic) theme(nejm) sheet("Table 3")
    confirm file "`output_dir'/_cov_strate_stress.xlsx"
    assert r(N_outcomes) == 2
    assert r(N_exposures) == 2
}
if _rc == 0 {
    display as result "  PASS: stratetab combined comprehensive stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab combined comprehensive stress test (error `=_rc')"
    local ++fail_count
}

* Test: stratetab data preservation
capture noisily {
    sysuse auto, clear
    local _orig_N = _N
    local _orig_k = c(k)
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_preserve.xlsx") outcomes(2)
    assert _N == `_orig_N'
    assert c(k) == `_orig_k'
}
if _rc == 0 {
    display as result "  PASS: stratetab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab data preservation (error `=_rc')"
    local ++fail_count
}

* Test: stratetab return values
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1" ///
        "`output_dir'/_cov_strate_o1e2" "`output_dir'/_cov_strate_o2e2") ///
        xlsx("`output_dir'/_cov_strate_returns.xlsx") outcomes(2) rateratio
    assert r(N_outcomes) == 2
    assert r(N_exposures) == 2
    assert r(N_rows) > 0
    assert "`r(xlsx)'" != ""
    assert "`r(sheet)'" != ""
    * Check returned matrices
    matrix list r(rates)
    matrix list r(ratios)
}
if _rc == 0 {
    display as result "  PASS: stratetab return values and matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab return values and matrices (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: error handling + varabbrev restore

**# SECTION 8: Error handling tests
* ============================================================

* Test: stratetab rejects invalid borderstyle
capture {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err.xlsx") outcomes(2) borderstyle(invalid)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects invalid borderstyle (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab invalid borderstyle expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects mismatched outcome labels
capture {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err2.xlsx") outcomes(2) outlabels("Only One")
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects mismatched outlabels count (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab mismatched outlabels expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects negative pyscale
capture {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err3.xlsx") outcomes(2) pyscale(-1)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects negative pyscale (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab negative pyscale expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects negative ratescale
capture {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err4.xlsx") outcomes(2) ratescale(-100)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects negative ratescale (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab negative ratescale expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects outcomes(0)
capture {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1") ///
        xlsx("`output_dir'/_cov_strate_err5.xlsx") outcomes(0)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects outcomes(0) (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab outcomes(0) expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test: stratetab rejects non-divisible file count
capture {
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_err6.xlsx") outcomes(3)
}
if _rc == 198 {
    display as result "  PASS: stratetab rejects non-divisible file count (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab non-divisible file count expected rc=198, got `=_rc'"
    local ++fail_count
}

* ============================================================
**# SECTION 9: varabbrev restore tests
* ============================================================

* Test: stratetab restores varabbrev on success
capture noisily {
    set varabbrev on
    sysuse auto, clear
    stratetab, using("`output_dir'/_cov_strate_o1e1" "`output_dir'/_cov_strate_o2e1") ///
        xlsx("`output_dir'/_cov_strate_va.xlsx") outcomes(2)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: stratetab restores varabbrev on success"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab restores varabbrev on success (error `=_rc')"
    local ++fail_count
}

* Test: stratetab restores varabbrev on error
capture noisily {
    set varabbrev on
    sysuse auto, clear
    capture stratetab, using("nonexistent_file") ///
        xlsx("`output_dir'/_cov_strate_va_err.xlsx") outcomes(1)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: stratetab restores varabbrev on error"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab restores varabbrev on error (error `=_rc')"
    local ++fail_count
}

set varabbrev off

* ============================================================

**# Migrated: xlsx success message

**# 2. stratetab xlsx success message is visible

**## 2a. Export confirmation message appears in log output
capture noisily {
    * Build minimal strate output
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _st_exp 0 "Unexposed" 1 "Exposed", replace
    label values exposure _st_exp
    tempfile st_rate
    save "`st_rate'.dta", replace

    * Run stratetab with xlsx and capture output to a file
    clear
    local stlog_path "`output_dir'/_rev1013_st_check"
    capture log close _stcheck
    log using "`stlog_path'", replace text name(_stcheck)
    stratetab, using(`st_rate') outcomes(1) ///
        xlsx("`output_dir'/_rev1013_stratetab.xlsx") ///
        sheet("Test")
    log close _stcheck

    * Read back the log and search for the success message
    tempname fh
    local found_msg 0
    file open `fh' using "`stlog_path'.log", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Exported to") > 0 {
            local found_msg 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found_msg' == 1
}
if _rc == 0 {
    display as result "  PASS [2a]: stratetab xlsx success message visible in output"
    local ++pass_count
}
else {
    display as error "  FAIL [2a]: stratetab xlsx success message not found (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_stratetab.xlsx"
capture erase "`output_dir'/_rev1013_st_check.log"



**# Migrated: r(xlsx)/r(sheet) populated

**# 6. stratetab xlsx r(xlsx) and r(sheet) populated (C1 regression)

**## 6a. r(xlsx) and r(sheet) are non-empty after successful xlsx export
capture noisily {
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _c1_exp 0 "Unexposed" 1 "Exposed", replace
    label values exposure _c1_exp
    tempfile c1_rate
    save "`c1_rate'.dta", replace

    clear
    local c1_xlsx "`output_dir'/_rev1013_c1_stratetab.xlsx"
    capture erase "`c1_xlsx'"
    stratetab, using(`c1_rate') outcomes(1) ///
        xlsx("`c1_xlsx'") sheet("C1Test")
    assert `"`r(xlsx)'"' != ""
    assert `"`r(sheet)'"' != ""
    capture confirm file "`c1_xlsx'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS [6a]: stratetab r(xlsx) and r(sheet) populated after xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL [6a]: stratetab r(xlsx)/r(sheet) empty or file missing (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_c1_stratetab.xlsx"



**# Migrated: sheet() validator

**# 3. stratetab sheet() validation — must use sheet validator, not path validator

**## 3a. Invalid sheet name with / rejected early (r(198))
capture {
    * We need strate output data for stratetab — create minimal fake
    clear
    set obs 4
    gen _D = _n
    gen _Y = _n * 100
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.5
    gen _Upper = _Rate * 1.5
    gen group = mod(_n, 2) + 1

    save "`output_dir'/_regfix_strate_data.dta", replace

    stratetab, using("`output_dir'/_regfix_strate_data") outcomes(1) ///
        xlsx("`output_dir'/_regfix_stratetab_badsheet.xlsx") sheet("bad/name")
}
if _rc == 198 {
    display as result "  PASS: stratetab sheet('bad/name') rejected with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab sheet('bad/name') expected r(198), got `=_rc'"
    local ++fail_count
}

**## 3b. Invalid sheet name with * rejected early (r(198))
capture {
    clear
    set obs 4
    gen _D = _n
    gen _Y = _n * 100
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.5
    gen _Upper = _Rate * 1.5
    gen group = mod(_n, 2) + 1
    save "`output_dir'/_regfix_strate_data2.dta", replace

    stratetab, using("`output_dir'/_regfix_strate_data2") outcomes(1) ///
        xlsx("`output_dir'/_regfix_stratetab_star.xlsx") sheet("bad*name")
}
if _rc == 198 {
    display as result "  PASS: stratetab sheet('bad*name') rejected with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab sheet('bad*name') expected r(198), got `=_rc'"
    local ++fail_count
}

**## 3c. Sheet name over 31 chars rejected early (r(198))
capture {
    clear
    set obs 4
    gen _D = _n
    gen _Y = _n * 100
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.5
    gen _Upper = _Rate * 1.5
    gen group = mod(_n, 2) + 1
    save "`output_dir'/_regfix_strate_data3.dta", replace

    stratetab, using("`output_dir'/_regfix_strate_data3") outcomes(1) ///
        xlsx("`output_dir'/_regfix_stratetab_long.xlsx") ///
        sheet("This sheet name is way too long for Excel to handle")
}
if _rc == 198 {
    display as result "  PASS: stratetab 31+ char sheet name rejected with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab long sheet name expected r(198), got `=_rc'"
    local ++fail_count
}



**# Migrated: console/frame modes without xlsx()

* Test 1: stratetab supports console-only mode without xlsx()
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp
    save "`rate1'.dta", replace

    sysuse auto, clear
    stratetab, using("`rate1'") outcomes(1) display
    assert r(N_rows) >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab display without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Test 2: stratetab supports frame() without xlsx()
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 15, cond(_n == 2, 25, 35))
    gen _Y = cond(_n == 1, 900, cond(_n == 2, 1000, 1100))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp2 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp2
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture frame drop issue_rates
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates, replace)
    assert r(frame) == "issue_rates"
    frame issue_rates: assert _N >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture frame drop issue_rates

* Test 3: stratetab supports display + frame() together without xlsx()
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 22, 32))
    gen _Y = cond(_n == 1, 950, cond(_n == 2, 1050, 1150))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp3 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp3
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture frame drop issue_rates2
    stratetab, using("`rate1'") outcomes(1) frame(issue_rates2, replace) display
    assert r(frame) == "issue_rates2"
    frame issue_rates2: assert _N >= 6
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab display + frame() without xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab display + frame() without xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture frame drop issue_rates2

* Test 4: stratetab rejects open without xlsx()
capture noisily {
    tempfile rate1
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 12, cond(_n == 2, 22, 32))
    gen _Y = cond(_n == 1, 950, cond(_n == 2, 1050, 1150))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label define issue_exp4 0 "Low" 1 "Medium" 2 "High"
    label values exposure issue_exp4
    save "`rate1'.dta", replace

    sysuse auto, clear
    capture stratetab, using("`rate1'") outcomes(1) open
    assert _rc == 198
    capture erase "`rate1'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab open requires xlsx()"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab open requires xlsx() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}


**# Migrated: basic feature test

* --- 7.11: stratetab basic test ---
capture noisily {
    * Create rate data
    clear
    set obs 200
    set seed 654
    gen exposure = cond(runiform() < 0.5, 1, 0)
    gen time = rexponential(1/5)
    gen event = runiform() < 0.3
    stset time, failure(event)
    capture erase "`output_dir'/_strate_tmp.dta"
    strate exposure, per(1000) output("`output_dir'/_strate_tmp", replace)
    capture erase "`output_dir'/test_stratetab_rates.xlsx"
    stratetab, using("`output_dir'/_strate_tmp") outcomes(1) ///
        xlsx("`output_dir'/test_stratetab_rates.xlsx") sheet("Rates")
    confirm file "`output_dir'/test_stratetab_rates.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab basic test"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab basic test (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: category validation preserves caller state

**# stratetab category validation preserves caller state

capture noisily {
    tempfile good dup blank mismatch
    _review_strate_file, basename("`good'")
    _review_strate_file, basename("`dup'") mode(duplicate)
    _review_strate_file, basename("`blank'") mode(blank)
    _review_strate_file, basename("`mismatch'") mode(mismatch)

    clear
    set obs 4
    gen byte id = _n
    gen str6 marker = "safe"
    local n_before = _N
    set varabbrev on

    capture noisily stratetab, using("`dup'") outcomes(1) display
    assert _rc == 198
    assert _N == `n_before'
    assert marker[2] == "safe"
    assert c(varabbrev) == "on"

    capture noisily stratetab, using("`blank'") outcomes(1) display
    assert _rc == 198
    assert _N == `n_before'
    assert marker[3] == "safe"
    assert c(varabbrev) == "on"

    capture noisily stratetab, using("`good'" "`mismatch'") outcomes(2) display
    assert _rc == 198
    assert _N == `n_before'
    assert marker[4] == "safe"
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: stratetab rejects duplicate/blank/mismatched categories and restores state"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab category validation cleanup contract (rc=`=_rc')"
    local ++fail_count
    capture set varabbrev off
}


**# Migrated: ratiodigits abbreviation

* T9: stratetab ratiodigits via `ratio` short form. Build two synthetic
*     strate output files (two exposure groups) and exercise the ratio()
*     abbreviation alongside rateratio.
quietly {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n==1, 25, cond(_n==2, 18, 32))
    gen _Y = cond(_n==1, 5000, cond(_n==2, 4500, 5200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.65
    gen _Upper = _Rate * 1.35
    label define _v103_lbl 0 "Never" 1 "Former" 2 "Current"
    label values exposure _v103_lbl
    save "`output_dir'/_v103_strate1.dta", replace

    replace _D = cond(_n==1, 30, cond(_n==2, 22, 28))
    replace _Y = cond(_n==1, 4800, cond(_n==2, 4600, 5100))
    replace _Rate = _D / _Y
    replace _Lower = _Rate * 0.65
    replace _Upper = _Rate * 1.35
    save "`output_dir'/_v103_strate2.dta", replace
}
capture noisily stratetab, using("`output_dir'/_v103_strate1" "`output_dir'/_v103_strate2") ///
    outcomes(1) rateratio ratio(3) border(thin) ///
    explabels("Group A" \ "Group B") ///
    xlsx("`output_dir'/_v103_stratetab.xlsx")
if _rc == 0 {
    display as result "  PASS T9: stratetab ratio short form"
    local ++pass_count
}
else {
    display as error "  FAIL T9: stratetab ratio short form (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}
capture erase "`output_dir'/_v103_strate1.dta"
capture erase "`output_dir'/_v103_strate2.dta"
capture erase "`output_dir'/_v103_stratetab.xlsx"




**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_stratetab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _stratetab
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_stratetab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _stratetab
