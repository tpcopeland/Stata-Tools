* test_stratetab.do - Dedicated QA for stratetab

clear all
set more off
set varabbrev on

capture log close _stratetab
log using "test_stratetab.log", replace text name(_stratetab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

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
local ++test_count
capture noisily {
    tempfile missing_rate
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
local ++test_count
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
local ++test_count
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
local ++test_count
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
local ++test_count
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
local ++test_count
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
	local ++test_count
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
	local ++test_count
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
	local ++test_count
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

	display as result "stratetab QA summary: `pass_count' passed, `fail_count' failed"
	if `fail_count' > 0 exit 1

log close _stratetab
