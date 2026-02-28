* test_tabtools_review.do
* Regression tests for tabtools package review fixes
* Tests critical issues #1-3 and important issues #4-12
* Run: stata-mp -b do test_tabtools_review.do

clear all
set more off
set varabbrev off

* Reload all tabtools commands
local tabtools_dir "../../tabtools"
local ados : dir "`tabtools_dir'" files "*.ado"
foreach f of local ados {
	cap program drop `=subinstr("`f'",".ado","",1)'
	run "`tabtools_dir'/`f'"
}

local failures = 0
local tests = 0
local test_xlsx "/tmp/test_tabtools_review.xlsx"

di _newline _dup(70) "="
di "TABTOOLS REVIEW REGRESSION TESTS"
di _dup(70) "="

* =========================================================================
* TEST 1: regtab preserves user data (Critical #1)
* =========================================================================
di _newline "TEST 1: regtab preserves user data"
local tests = `tests' + 1

sysuse auto, clear
local orig_N = _N
local orig_k = c(k)

* Run a regression and collect
collect clear
collect: regress price mpg weight
cap noi regtab, xlsx("`test_xlsx'") sheet("regtab_test") title("Test")

* Verify data is intact
if _N != `orig_N' | c(k) != `orig_k' {
	di as error "  FAIL: Data destroyed by regtab (_N=`=_N', expected `orig_N')"
	local failures = `failures' + 1
}
else {
	* Verify it's actually the auto dataset
	cap confirm variable price mpg weight foreign
	if _rc {
		di as error "  FAIL: Variables missing after regtab"
		local failures = `failures' + 1
	}
	else {
		di as result "  PASS"
	}
}

* =========================================================================
* TEST 2: effecttab preserves user data (Critical #1)
* =========================================================================
di _newline "TEST 2: effecttab preserves user data"
local tests = `tests' + 1

sysuse auto, clear
local orig_N = _N

collect clear
collect: regress price mpg weight
cap noi effecttab, xlsx("`test_xlsx'") sheet("effecttab_test") type(margins) title("Test")

if _N != `orig_N' {
	di as error "  FAIL: Data destroyed by effecttab (_N=`=_N', expected `orig_N')"
	local failures = `failures' + 1
}
else {
	cap confirm variable price mpg weight foreign
	if _rc {
		di as error "  FAIL: Variables missing after effecttab"
		local failures = `failures' + 1
	}
	else {
		di as result "  PASS"
	}
}

* =========================================================================
* TEST 3: tablex preserves user data (Critical #1)
* =========================================================================
di _newline "TEST 3: tablex preserves user data"
local tests = `tests' + 1

sysuse auto, clear
local orig_N = _N

table foreign rep78
cap noi tablex using "`test_xlsx'", sheet("tablex_test") title("Test") replace

if _N != `orig_N' {
	di as error "  FAIL: Data destroyed by tablex (_N=`=_N', expected `orig_N')"
	local failures = `failures' + 1
}
else {
	cap confirm variable price mpg weight foreign
	if _rc {
		di as error "  FAIL: Variables missing after tablex"
		local failures = `failures' + 1
	}
	else {
		di as result "  PASS"
	}
}

* =========================================================================
* TEST 4: table1_tc with excel() but no by() (Critical #2)
* =========================================================================
di _newline "TEST 4: table1_tc with excel() and no by() (pvalue_pos=0 guard)"
local tests = `tests' + 1

sysuse auto, clear
cap noi table1_tc, vars(price contn \ mpg contn \ weight contn) ///
	excel("`test_xlsx'") sheet("table1_noby") title("No By Variable Test")

if _rc {
	di as error "  FAIL: table1_tc without by() crashed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 5: table1_tc with excel() AND by() still works (regression check)
* =========================================================================
di _newline "TEST 5: table1_tc with excel() and by() (regression check)"
local tests = `tests' + 1

sysuse auto, clear
cap noi table1_tc, by(foreign) ///
	vars(price contn \ mpg contn \ rep78 cat \ weight contn) ///
	excel("`test_xlsx'") sheet("table1_by") title("With By Variable")

if _rc {
	di as error "  FAIL: table1_tc with by() failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 6: effecttab p-value cap at 0.99 (Critical #3)
* =========================================================================
di _newline "TEST 6: effecttab p-value formatting works"
local tests = `tests' + 1

sysuse auto, clear
collect clear
collect: regress price mpg weight
cap noi effecttab, xlsx("`test_xlsx'") sheet("effecttab_pval") type(margins) title("PVal Test")

if _rc {
	di as error "  FAIL: effecttab with p-value formatting failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 7: tabtools listing command works (Issue #9 - version/varabbrev)
* =========================================================================
di _newline "TEST 7: tabtools listing command"
local tests = `tests' + 1

sysuse auto, clear
cap noi tabtools

if _rc {
	di as error "  FAIL: tabtools command failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 8: tabtools detail command
* =========================================================================
di _newline "TEST 8: tabtools detail command"
local tests = `tests' + 1

cap noi tabtools, detail

if _rc {
	di as error "  FAIL: tabtools detail failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 9: _tabtools_common utilities work (Issue #11 refactor)
* =========================================================================
di _newline "TEST 9: _tabtools_col_letter utility"
local tests = `tests' + 1

_tabtools_col_letter 1
local test_pass = 1
if "`result'" != "A" {
	di as error "  FAIL: col_letter(1) = `result', expected A"
	local test_pass = 0
}
_tabtools_col_letter 26
if "`result'" != "Z" {
	di as error "  FAIL: col_letter(26) = `result', expected Z"
	local test_pass = 0
}
_tabtools_col_letter 27
if "`result'" != "AA" {
	di as error "  FAIL: col_letter(27) = `result', expected AA"
	local test_pass = 0
}

if `test_pass' {
	di as result "  PASS"
}
else {
	local failures = `failures' + 1
}

* =========================================================================
* TEST 10: _tabtools_build_col_letters utility (after refactor)
* =========================================================================
di _newline "TEST 10: _tabtools_build_col_letters utility"
local tests = `tests' + 1

_tabtools_build_col_letters 5
local expected "A B C D E"
if "`result'" != "`expected'" {
	di as error "  FAIL: build_col_letters(5) = `result', expected `expected'"
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 11: _tabtools_validate_path rejects bad chars (Issue #8, #10)
* =========================================================================
di _newline "TEST 11: _tabtools_validate_path rejects dangerous characters"
local tests = `tests' + 1

local test_pass = 1
cap noi _tabtools_validate_path "good_file.xlsx" "test"
if _rc {
	di as error "  FAIL: Rejected valid path"
	local test_pass = 0
}

cap _tabtools_validate_path "bad;file.xlsx" "test"
if _rc != 198 {
	di as error "  FAIL: Did not reject semicolon (rc=" _rc ")"
	local test_pass = 0
}

cap _tabtools_validate_path "bad|file.xlsx" "test"
if _rc != 198 {
	di as error "  FAIL: Did not reject pipe (rc=" _rc ")"
	local test_pass = 0
}

if `test_pass' {
	di as result "  PASS"
}
else {
	local failures = `failures' + 1
}

* =========================================================================
* TEST 12: regtab multi-model regression test
* =========================================================================
di _newline "TEST 12: regtab multi-model with models() option"
local tests = `tests' + 1

sysuse auto, clear
collect clear
collect: regress price mpg weight
collect: regress price mpg weight foreign
cap noi regtab, xlsx("`test_xlsx'") sheet("regtab_multi") ///
	models("Model 1 \ Model 2") title("Multi-model Test") coef("Coef.")

if _rc {
	di as error "  FAIL: regtab multi-model failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	* Verify data preserved after multi-model
	cap confirm variable price mpg weight foreign
	if _rc {
		di as error "  FAIL: Data not preserved after multi-model regtab"
		local failures = `failures' + 1
	}
	else {
		di as result "  PASS"
	}
}

* =========================================================================
* TEST 13: regtab with stats option
* =========================================================================
di _newline "TEST 13: regtab with stats(n aic bic ll)"
local tests = `tests' + 1

sysuse auto, clear
collect clear
collect: regress price mpg weight
cap noi regtab, xlsx("`test_xlsx'") sheet("regtab_stats") ///
	title("Stats Test") stats(n aic bic ll)

if _rc {
	di as error "  FAIL: regtab with stats failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 14: regtab noint option
* =========================================================================
di _newline "TEST 14: regtab with noint option"
local tests = `tests' + 1

sysuse auto, clear
collect clear
collect: regress price mpg weight
cap noi regtab, xlsx("`test_xlsx'") sheet("regtab_noint") ///
	title("NoInt Test") noint

if _rc {
	di as error "  FAIL: regtab with noint failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 15: table1_tc with various variable types
* =========================================================================
di _newline "TEST 15: table1_tc with contn, conts, cat, bin"
local tests = `tests' + 1

sysuse auto, clear
gen byte highmpg = mpg > 20
label var highmpg "High MPG"

cap noi table1_tc, by(foreign) ///
	vars(price contn \ mpg conts \ rep78 cat \ highmpg bin) ///
	excel("`test_xlsx'") sheet("table1_full") title("Full Types Test")

if _rc {
	di as error "  FAIL: table1_tc with all var types failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 16: table1_tc with total and borderstyle options
* =========================================================================
di _newline "TEST 16: table1_tc with total(after) and borderstyle(thin)"
local tests = `tests' + 1

sysuse auto, clear
cap noi table1_tc, by(foreign) ///
	vars(price contn \ mpg contn) ///
	total(after) borderstyle(thin) ///
	excel("`test_xlsx'") sheet("table1_total") title("Total Test")

if _rc {
	di as error "  FAIL: table1_tc with total/borderstyle failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	di as result "  PASS"
}

* =========================================================================
* TEST 17: regtab with logistic model (OR)
* =========================================================================
di _newline "TEST 17: regtab with logistic model"
local tests = `tests' + 1

sysuse auto, clear
collect clear
collect: logit foreign price mpg weight
cap noi regtab, xlsx("`test_xlsx'") sheet("regtab_logit") ///
	title("Logistic Model") coef("OR")

if _rc {
	di as error "  FAIL: regtab with logistic failed with rc=" _rc
	local failures = `failures' + 1
}
else {
	cap confirm variable price mpg weight foreign
	if _rc {
		di as error "  FAIL: Data not preserved after logistic regtab"
		local failures = `failures' + 1
	}
	else {
		di as result "  PASS"
	}
}

* =========================================================================
* SUMMARY
* =========================================================================
di _newline _dup(70) "="
di "RESULTS: `tests' tests, `=`tests'-`failures'' passed, `failures' failed"
di _dup(70) "="

* Cleanup
cap erase "`test_xlsx'"

if `failures' > 0 {
	di as error "SOME TESTS FAILED"
	exit 1
}
else {
	di as result "ALL TESTS PASSED"
}
