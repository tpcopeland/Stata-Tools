* test_hrtab.do — QA suite for hrtab command
* Usage: cd into qa/ directory, then: stata-mp -b do test_hrtab.do

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local repo_dir = subinstr("`pkg_dir'", "/tabtools", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =========================================================================
**# SETUP: Create synthetic survival data
* =========================================================================

capture program drop _hrtab_make_data
program define _hrtab_make_data
	clear
	set obs 200
	set seed 12345
	gen long pid = _n
	gen byte treatment = cond(_n <= 100, 0, 1)
	label define trt_lbl 0 "Control" 1 "Treated"
	label values treatment trt_lbl
	gen byte sex = runiformint(0, 1)
	label define sex_lbl 0 "Male" 1 "Female"
	label values sex sex_lbl
	gen double age = rnormal(60, 10)
	gen double dose = rnormal(50, 15)
	label var dose "Cumulative dose, per unit"
	gen double followup = rexponential(1/5)
	replace followup = min(followup, 10)
	gen byte died = runiform() < 0.3
	gen byte event_type = 0
	replace event_type = 1 if runiform() < 0.2
	replace event_type = 2 if event_type == 0 & runiform() < 0.15
	label define evt_lbl 0 "Censored" 1 "CV Death" 2 "Non-CV Death"
	label values event_type evt_lbl
	gen byte mi_event = runiform() < 0.25
	gen byte stroke_event = runiform() < 0.15
	gen double followup_mi = rexponential(1/5)
	replace followup_mi = min(followup_mi, 10)
	gen double followup_stroke = rexponential(1/5)
	replace followup_stroke = min(followup_stroke, 10)
	gen byte duration_cat = cond(dose < 40, 0, cond(dose < 60, 1, 2))
	label define dur_lbl 0 "Short" 1 "Medium" 2 "Long"
	label values duration_cat dur_lbl
end

* Temp xlsx path for output tests
tempfile _tmpxlsx
local tmpxlsx "`_tmpxlsx'.xlsx"

* =========================================================================
**# 1. BASIC FUNCTIONALITY
* =========================================================================

**## 1.1 Single outcome, existing stset, stcox
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) display
	assert r(models) == 1
	assert r(panels) == 1
	assert r(outcomes) == 1
	assert "`r(cmd)'" == "stcox"
}
if _rc == 0 {
	display as result "  PASS: 1.1 Basic stcox, single outcome, existing stset"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.1 Basic stcox (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.1"
}

**## 1.2 Single outcome with covars
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) covars(age sex) display
	assert r(models) == 2
}
if _rc == 0 {
	display as result "  PASS: 1.2 stcox with covars (unadjusted + adjusted)"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.2 stcox with covars (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.2"
}

**## 1.3 Multiple outcomes
local ++test_count
capture noisily {
	_hrtab_make_data
	hrtab, exposure(i.treatment) model(stcox) ///
		outcome(mi_event \ stroke_event) ///
		time(followup_mi \ followup_stroke) ///
		stsetopts(id(pid)) display
	assert r(outcomes) == 2
	assert r(panels) == 1
}
if _rc == 0 {
	display as result "  PASS: 1.3 Multiple outcomes"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.3 Multiple outcomes (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.3"
}

**## 1.4 Multiple exposure panels
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment \ i.duration_cat) model(stcox) display
	assert r(panels) == 2
}
if _rc == 0 {
	display as result "  PASS: 1.4 Multiple exposure panels"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.4 Multiple exposure panels (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.4"
}

**## 1.5 Continuous exposure
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(c.dose) model(stcox) display
	assert r(panels) == 1
	assert r(models) == 1
}
if _rc == 0 {
	display as result "  PASS: 1.5 Continuous exposure"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.5 Continuous exposure (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.5"
}

**## 1.6 Mixed categorical and continuous exposures
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment \ c.dose) model(stcox) ///
		covars(age) display
	assert r(panels) == 2
	assert r(models) == 2
}
if _rc == 0 {
	display as result "  PASS: 1.6 Mixed categorical + continuous exposures"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.6 Mixed exposures (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.6"
}

* =========================================================================
**# 2. COMPETING RISKS
* =========================================================================

**## 2.1 stcrreg with failvalue
local ++test_count
capture noisily {
	_hrtab_make_data
	hrtab, exposure(i.treatment) model(stcrreg) ///
		outcome(event_type) time(followup) failvalue(1 \ 2) ///
		stsetopts(id(pid)) nolog display
	assert r(outcomes) == 2
	assert "`r(cmd)'" == "stcrreg"
}
if _rc == 0 {
	display as result "  PASS: 2.1 stcrreg with failvalue (competing risks)"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.1 stcrreg with failvalue (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.1"
}

**## 2.2 finegray with failvalue
local ++test_count
capture noisily {
	_hrtab_make_data
	hrtab, exposure(i.treatment) model(finegray) ///
		outcome(event_type) time(followup) failvalue(1) ///
		stsetopts(id(pid)) nolog display
	assert r(outcomes) == 1
	assert "`r(cmd)'" == "finegray"
}
if _rc == 0 {
	display as result "  PASS: 2.2 finegray with failvalue"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.2 finegray with failvalue (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.2"
}

**## 2.3 stcrreg with single failvalue + covars
local ++test_count
capture noisily {
	_hrtab_make_data
	hrtab, exposure(i.treatment) model(stcrreg) ///
		outcome(event_type) time(followup) failvalue(1) ///
		stsetopts(id(pid)) covars(age sex) nolog display
	assert r(outcomes) == 1
	assert r(models) == 2
}
if _rc == 0 {
	display as result "  PASS: 2.3 stcrreg single failvalue + covars"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.3 stcrreg single failvalue + covars (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.3"
}

* =========================================================================
**# 3. OPTIONS
* =========================================================================

**## 3.1 nounadjusted
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) ///
		covars(age sex) nounadjusted display
	assert r(models) == 1
}
if _rc == 0 {
	display as result "  PASS: 3.1 nounadjusted option"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.1 nounadjusted (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.1"
}

**## 3.2 Multiple covariate sets
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) ///
		covars(age \ age sex) display
	assert r(models) == 3
}
if _rc == 0 {
	display as result "  PASS: 3.2 Multiple covariate sets (3 models)"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.2 Multiple covariate sets (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.2"
}

**## 3.3 pvalue option
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) ///
		covars(age) pvalue display
}
if _rc == 0 {
	display as result "  PASS: 3.3 pvalue option"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.3 pvalue (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.3"
}

**## 3.4 nopytime + noevents
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) nopytime noevents display
}
if _rc == 0 {
	display as result "  PASS: 3.4 nopytime + noevents"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.4 nopytime + noevents (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.4"
}

**## 3.5 Custom labels
local ++test_count
capture noisily {
	_hrtab_make_data
	hrtab, exposure(i.treatment \ i.duration_cat) model(stcox) ///
		outcome(mi_event \ stroke_event) ///
		time(followup_mi \ followup_stroke) ///
		stsetopts(id(pid)) ///
		covars(age sex) ///
		outlabels("MI" \ "Stroke") ///
		explabels("Treatment" \ "Duration") ///
		modellabels("Crude" \ "Adjusted") ///
		reflabel("1.00") nolog display
	assert r(panels) == 2
	assert r(outcomes) == 2
}
if _rc == 0 {
	display as result "  PASS: 3.5 Custom labels (outlabels, explabels, modellabels, reflabel)"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.5 Custom labels (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.5"
}

**## 3.6 effect() override
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) effect("aHR") display
}
if _rc == 0 {
	display as result "  PASS: 3.6 effect() override to aHR"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.6 effect() override (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.6"
}

**## 3.7 digits and pydigits
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) ///
		digits(3) pydigits(1) pyscale(1000) display
}
if _rc == 0 {
	display as result "  PASS: 3.7 digits(3) pydigits(1) pyscale(1000)"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.7 digits/pydigits/pyscale (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.7"
}

**## 3.8 level(90) — 90% CI
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) level(90) display
}
if _rc == 0 {
	display as result "  PASS: 3.8 level(90) confidence interval"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.8 level(90) (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.8"
}

**## 3.9 dots option
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) covars(age) dots nolog
}
if _rc == 0 {
	display as result "  PASS: 3.9 dots progress indicator"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.9 dots (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.9"
}

**## 3.10 ib# explicit base level
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(ib1.duration_cat) model(stcox) display
	assert r(panels) == 1
}
if _rc == 0 {
	display as result "  PASS: 3.10 Explicit base level ib1.duration_cat"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.10 Explicit base level (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.10"
}

**## 3.11 modelopts (strata)
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) ///
		modelopts(strata(sex)) nolog display
}
if _rc == 0 {
	display as result "  PASS: 3.11 modelopts(strata(sex))"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.11 modelopts (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.11"
}

* =========================================================================
**# 4. EXCEL OUTPUT
* =========================================================================

**## 4.1 Basic xlsx export
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture erase "`tmpxlsx'"
	hrtab, exposure(i.treatment) model(stcox) ///
		covars(age sex) xlsx("`tmpxlsx'") nolog
	assert "`r(xlsx)'" != ""
	assert "`r(sheet)'" == "Results"
	confirm file "`tmpxlsx'"
}
if _rc == 0 {
	display as result "  PASS: 4.1 Basic xlsx export"
	local ++pass_count
}
else {
	display as error "  FAIL: 4.1 xlsx export (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 4.1"
}

**## 4.2 xlsx with theme and formatting
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture erase "`tmpxlsx'"
	hrtab, exposure(i.treatment) model(stcox) ///
		covars(age) xlsx("`tmpxlsx'") ///
		title("Table 2") subtitle("Cox regression") ///
		footnote("Adjusted for age") ///
		theme(lancet) zebra headershade nolog
	confirm file "`tmpxlsx'"
}
if _rc == 0 {
	display as result "  PASS: 4.2 xlsx with theme, zebra, headershade, title, footnote"
	local ++pass_count
}
else {
	display as error "  FAIL: 4.2 xlsx with formatting (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 4.2"
}

**## 4.3 xlsx with pvalue, boldp, highlight
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture erase "`tmpxlsx'"
	hrtab, exposure(i.treatment) model(stcox) ///
		covars(age) pvalue xlsx("`tmpxlsx'") ///
		boldp(0.05) highlight(0.05) nolog
	confirm file "`tmpxlsx'"
}
if _rc == 0 {
	display as result "  PASS: 4.3 xlsx with pvalue + boldp + highlight"
	local ++pass_count
}
else {
	display as error "  FAIL: 4.3 xlsx pvalue formatting (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 4.3"
}

**## 4.4 csv export
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	tempfile _tmpcsv
	local tmpcsv "`_tmpcsv'.csv"
	capture erase "`tmpxlsx'"
	hrtab, exposure(i.treatment) model(stcox) ///
		xlsx("`tmpxlsx'") csv("`tmpcsv'") nolog
	confirm file "`tmpcsv'"
}
if _rc == 0 {
	display as result "  PASS: 4.4 csv export"
	local ++pass_count
}
else {
	display as error "  FAIL: 4.4 csv export (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 4.4"
}

**## 4.5 Custom sheet name
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture erase "`tmpxlsx'"
	hrtab, exposure(i.treatment) model(stcox) ///
		xlsx("`tmpxlsx'") sheet("HR Table") nolog
	assert "`r(sheet)'" == "HR Table"
}
if _rc == 0 {
	display as result "  PASS: 4.5 Custom sheet name"
	local ++pass_count
}
else {
	display as error "  FAIL: 4.5 Custom sheet (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 4.5"
}

* =========================================================================
**# 5. ERROR HANDLING
* =========================================================================

**## 5.1 Missing exposure
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, model(stcox) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.1 Error: missing exposure()"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.1 Missing exposure error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.1"
}

**## 5.2 Missing model
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.2 Error: missing model()"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.2 Missing model error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.2"
}

**## 5.3 Invalid model name
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment) model(logistic) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.3 Error: invalid model name"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.3 Invalid model error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.3"
}

**## 5.4 outcome() without time()
local ++test_count
capture noisily {
	_hrtab_make_data
	capture hrtab, exposure(i.treatment) model(stcox) outcome(died) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.4 Error: outcome() without time()"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.4 Missing time error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.4"
}

**## 5.5 nounadjusted without covars
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment) model(stcox) nounadjusted display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.5 Error: nounadjusted without covars"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.5 nounadjusted error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.5"
}

**## 5.6 finegray without id in stsetopts
local ++test_count
capture noisily {
	_hrtab_make_data
	capture hrtab, exposure(i.treatment) model(finegray) ///
		outcome(event_type) time(followup) failvalue(1) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.6 Error: finegray without stsetopts(id())"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.6 finegray id error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.6"
}

**## 5.7 stcrreg without failvalue or modelopts(compete)
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment) model(stcrreg) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.7 Error: stcrreg without failvalue/compete"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.7 stcrreg compete error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.7"
}

**## 5.8 Mismatched outlabels count
local ++test_count
capture noisily {
	_hrtab_make_data
	capture hrtab, exposure(i.treatment) model(stcox) ///
		outcome(mi_event \ stroke_event) ///
		time(followup_mi \ followup_stroke) ///
		stsetopts(id(pid)) ///
		outlabels("MI") display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.8 Error: outlabels count mismatch"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.8 outlabels mismatch (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.8"
}

**## 5.9 Mismatched explabels count
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment \ i.sex) model(stcox) ///
		explabels("Treatment") display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.9 Error: explabels count mismatch"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.9 explabels mismatch (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.9"
}

**## 5.10 Invalid exposure notation (no prefix)
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(treatment) model(stcox) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.10 Error: exposure without factor notation"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.10 exposure notation error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.10"
}

**## 5.11 No stset and no outcome
local ++test_count
capture noisily {
	_hrtab_make_data
	* data is NOT stset
	capture hrtab, exposure(i.treatment) model(stcox) display
	assert _rc == 119
}
if _rc == 0 {
	display as result "  PASS: 5.11 Error: no stset and no outcome"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.11 no stset error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.11"
}

**## 5.12 Invalid digits range
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment) model(stcox) digits(0) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.12 Error: digits(0) out of range"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.12 digits range error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.12"
}

**## 5.13 Nonexistent exposure variable
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.nonexistent) model(stcox) display
	assert _rc == 111
}
if _rc == 0 {
	display as result "  PASS: 5.13 Error: nonexistent exposure variable"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.13 nonexistent exposure (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.13"
}

**## 5.14 failvalue without outcome
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture hrtab, exposure(i.treatment) model(stcox) failvalue(1) display
	assert _rc == 198
}
if _rc == 0 {
	display as result "  PASS: 5.14 Error: failvalue without outcome"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.14 failvalue without outcome (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.14"
}

* =========================================================================
**# 6. RETURN VALUES
* =========================================================================

**## 6.1 All expected r() values present
local ++test_count
local t6_pass = 1
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	capture erase "`tmpxlsx'"
	hrtab, exposure(i.treatment \ i.duration_cat) model(stcox) ///
		covars(age \ age sex) xlsx("`tmpxlsx'") nolog
}
if _rc != 0 {
	display as error "  FAIL [6.1.run]: command errored (error `=_rc')"
	local t6_pass = 0
}
else {
	* Check scalars
	if r(models) == 6 {
		display as result "  PASS [6.1.models]: r(models)==6 (2 panels x 3 models)"
	}
	else {
		display as error "  FAIL [6.1.models]: expected 6, got `=r(models)'"
		local t6_pass = 0
	}
	if r(outcomes) == 1 {
		display as result "  PASS [6.1.outcomes]: r(outcomes)==1"
	}
	else {
		display as error "  FAIL [6.1.outcomes]: expected 1, got `=r(outcomes)'"
		local t6_pass = 0
	}
	if r(panels) == 2 {
		display as result "  PASS [6.1.panels]: r(panels)==2"
	}
	else {
		display as error "  FAIL [6.1.panels]: expected 2, got `=r(panels)'"
		local t6_pass = 0
	}
	if r(N_unadjusted) > 0 {
		display as result "  PASS [6.1.N_unadj]: r(N_unadjusted)=`=r(N_unadjusted)'"
	}
	else {
		display as error "  FAIL [6.1.N_unadj]: expected > 0"
		local t6_pass = 0
	}

	* Check macros
	if "`r(cmd)'" == "stcox" {
		display as result "  PASS [6.1.cmd]: r(cmd)==stcox"
	}
	else {
		display as error "  FAIL [6.1.cmd]: expected stcox, got `r(cmd)'"
		local t6_pass = 0
	}
	if "`r(xlsx)'" != "" {
		display as result "  PASS [6.1.xlsx]: r(xlsx) populated"
	}
	else {
		display as error "  FAIL [6.1.xlsx]: r(xlsx) empty"
		local t6_pass = 0
	}
	if "`r(sheet)'" == "Results" {
		display as result "  PASS [6.1.sheet]: r(sheet)==Results"
	}
	else {
		display as error "  FAIL [6.1.sheet]: expected Results, got `r(sheet)'"
		local t6_pass = 0
	}
}
if `t6_pass' == 1 {
	local ++pass_count
}
else {
	local ++fail_count
	local failed_tests "`failed_tests' 6.1"
}

* =========================================================================
**# 7. DATA PRESERVATION
* =========================================================================

**## 7.1 Dataset unchanged after hrtab
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	local _pre_N = _N
	local _pre_vars : char _dta[_varnames_]
	quietly describe, short
	local _pre_nvars = r(k)
	quietly summarize age
	local _pre_mean = r(mean)

	hrtab, exposure(i.treatment) model(stcox) covars(age) nolog

	* Verify preservation
	assert _N == `_pre_N'
	quietly describe, short
	assert r(k) == `_pre_nvars'
	quietly summarize age
	assert abs(r(mean) - `_pre_mean') < 1e-10
}
if _rc == 0 {
	display as result "  PASS: 7.1 Dataset preserved (N, vars, values)"
	local ++pass_count
}
else {
	display as error "  FAIL: 7.1 Data preservation (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 7.1"
}

**## 7.2 stset preserved in single-outcome mode
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	local _pre_st "`_dta[st_bt]'"

	hrtab, exposure(i.treatment) model(stcox) nolog

	* stset should be intact
	capture st_is 2 analysis
	assert _rc == 0
}
if _rc == 0 {
	display as result "  PASS: 7.2 stset preserved after single-outcome hrtab"
	local ++pass_count
}
else {
	display as error "  FAIL: 7.2 stset preservation (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 7.2"
}

* =========================================================================
**# 8. VARABBREV RESTORE
* =========================================================================

**## 8.1 Varabbrev restored on success
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	set varabbrev on
	hrtab, exposure(i.treatment) model(stcox) nolog
	assert c(varabbrev) == "on"
}
if _rc == 0 {
	display as result "  PASS: 8.1 varabbrev restored on success"
	local ++pass_count
}
else {
	display as error "  FAIL: 8.1 varabbrev restore success (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 8.1"
}

**## 8.2 Varabbrev restored on error
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	set varabbrev on
	capture hrtab, exposure(i.treatment) model(badmodel) display
	assert c(varabbrev) == "on"
}
if _rc == 0 {
	display as result "  PASS: 8.2 varabbrev restored on error"
	local ++pass_count
}
else {
	display as error "  FAIL: 8.2 varabbrev restore error (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 8.2"
}

**## 8.3 Varabbrev restored when user had it off
local ++test_count
capture noisily {
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	set varabbrev off
	hrtab, exposure(i.treatment) model(stcox) nolog
	assert c(varabbrev) == "off"
	set varabbrev on
}
if _rc == 0 {
	display as result "  PASS: 8.3 varabbrev off preserved (no leak to on)"
	local ++pass_count
}
else {
	display as error "  FAIL: 8.3 varabbrev off preservation (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 8.3"
	set varabbrev on
}

* =========================================================================
**# 9. HELPER AUTO-LOADING
* =========================================================================

**## 9.1 Auto-load after fresh install
local ++test_count
capture noisily {
	capture ado uninstall tabtools
	quietly net install tabtools, from("`pkg_dir'") replace
	_hrtab_make_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.treatment) model(stcox) nolog
	assert r(models) == 1
}
if _rc == 0 {
	display as result "  PASS: 9.1 Helper auto-loads after fresh net install"
	local ++pass_count
}
else {
	display as error "  FAIL: 9.1 Helper auto-load (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 9.1"
}

* =========================================================================
**# SUMMARY
* =========================================================================

display ""
display as result "=== hrtab QA Summary: `pass_count' passed, `fail_count' failed out of `test_count' tests ==="
if `fail_count' > 0 {
	display as error "Failed tests:`failed_tests'"
	exit 1
}
else {
	display as result "ALL TESTS PASSED"
}
