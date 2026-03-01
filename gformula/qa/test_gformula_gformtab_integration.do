/*******************************************************************************
* test_gformula_gformtab_integration.do
*
* Purpose: Integration test that runs gformula on synthetic data, then pipes
*          results to gformtab, and validates Excel output with check_xlsx.py
*
* Tests:
*   1. gformula mediation (OBE) → gformtab with normal CIs
*   2. gformula mediation (OBE) → gformtab with percentile CIs
*   3. gformula mediation (OBE+CDE) → gformtab with control()
*   4. e() results survive through gformtab call
*   5. estimates store works after gformula (eclass proof)
*   6. Excel output validated with check_xlsx.py
*
* Prerequisites:
*   - gformula.ado in gformula/
*   - gformtab.ado in gformula/
*   - python3 with openpyxl
*
* Run: stata-mp -b do ../../_devkit/_testing/test_gformula_gformtab_integration.do
*
* Author: Timothy P Copeland
* Date: 2026-02-27
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================

* Detect Stata-Tools repo root (where released packages live)
capture confirm file "gformula/gformtab.ado"
if _rc == 0 {
	global STATA_TOOLS_ROOT "`c(pwd)'"
}
else {
	global STATA_TOOLS_ROOT "/home/`c(username)'/Stata-Tools"
}

* Stata-Dev repo root (for test infrastructure)
global DEVKIT_ROOT "/home/`c(username)'/Stata-Dev"
global TESTING_DIR "${DEVKIT_ROOT}/_devkit/_testing"
global DATA_DIR "${TESTING_DIR}/data"
global TOOLS_DIR "${TESTING_DIR}/tools"

* Load packages from Stata-Tools
capture program drop gformula
capture program drop _gformula_bootstrap
capture program drop _gformula_detangle
capture program drop _gformula_formatline
run "${STATA_TOOLS_ROOT}/gformula/gformula.ado"
adopath ++ "${STATA_TOOLS_ROOT}/gformula"
capture program drop gformtab
run "${STATA_TOOLS_ROOT}/gformula/gformtab.ado"

* Ensure data directory exists
capture mkdir "${DATA_DIR}"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture log close _all
log using "${TESTING_DIR}/test_gformula_gformtab_integration.log", replace name(inttest)

display as text "{hline 70}"
display as text "GFORMULA + GFORMTAB INTEGRATION TESTS"
display as text "{hline 70}"

* =============================================================================
* Generate synthetic mediation dataset
* =============================================================================
* True DGP: x → m → y with confounding by c
*   c ~ N(0,1)
*   x ~ Bernoulli(invlogit(-0.5 + 0.3*c))
*   m ~ Bernoulli(invlogit(-1 + 0.8*x + 0.5*c))
*   y ~ Bernoulli(invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
* This gives a moderate TCE with partial mediation through m.

clear
set seed 20260227
set obs 1000
gen double c = rnormal()
gen double x = rbinomial(1, invlogit(-0.5 + 0.3*c))
gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))

display as text "Synthetic data: N=`=_N', mean(y)=`=string(r(mean), "%4.3f")'"
tab x m

* =============================================================================
* TEST 1: gformula OBE → gformtab with normal CIs
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gformula OBE → gformtab (normal CI)"
display as text "{hline 50}"

capture noisily {
	gformula y m x c, outcome(y) mediation obe ///
		exposure(x) mediator(m) ///
		commands(m: logit, y: logit) ///
		equations(m: x c, y: m x c) ///
		base_confs(c) sim(500) samples(50) seed(1)

	* Verify e() is populated
	assert "`e(cmd)'" == "gformula"
	assert "`e(analysis_type)'" == "mediation"
	confirm scalar e(tce)
	confirm scalar e(nde)
	confirm scalar e(nie)
	confirm scalar e(pm)
	confirm matrix e(b)
	confirm matrix e(V)
	confirm matrix e(se)
	confirm matrix e(ci_normal)

	* Export to Excel
	gformtab, xlsx("${DATA_DIR}/_test_integration_normal.xlsx") ///
		sheet("Mediation OBE") ///
		title("Table 1. Causal Mediation Analysis (OBE)")

	confirm file "${DATA_DIR}/_test_integration_normal.xlsx"
	display as result "  PASSED: gformula → gformtab pipeline works (normal CI)"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 2: gformula OBE → gformtab with percentile CIs
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gformula OBE → gformtab (percentile CI)"
display as text "{hline 50}"

capture noisily {
	* Re-run gformula with all CI types
	gformula y m x c, outcome(y) mediation obe ///
		exposure(x) mediator(m) ///
		commands(m: logit, y: logit) ///
		equations(m: x c, y: m x c) ///
		base_confs(c) sim(500) samples(50) seed(1) all

	* Check all CI matrices exist
	confirm matrix e(ci_normal)
	confirm matrix e(ci_percentile)
	confirm matrix e(ci_bc)
	confirm matrix e(ci_bca)

	gformtab, xlsx("${DATA_DIR}/_test_integration_pctile.xlsx") ///
		sheet("Percentile") ci(percentile) ///
		title("Table 2. Mediation Results (Percentile CIs)")

	confirm file "${DATA_DIR}/_test_integration_pctile.xlsx"
	display as result "  PASSED: gformtab with percentile CIs"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 3: gformula OBE + control() → gformtab with CDE
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gformula OBE+CDE → gformtab"
display as text "{hline 50}"

capture noisily {
	gformula y m x c, outcome(y) mediation obe ///
		exposure(x) mediator(m) ///
		commands(m: logit, y: logit) ///
		equations(m: x c, y: m x c) ///
		base_confs(c) control(0) sim(500) samples(50) seed(1)

	* CDE should exist
	confirm scalar e(cde)
	confirm scalar e(se_cde)

	* Check e(b) has 5 columns (tce nde nie pm cde)
	tempname _b
	matrix `_b' = e(b)
	assert colsof(`_b') == 5
	local _cols : colnames `_b'
	local _last : word 5 of `_cols'
	assert "`_last'" == "cde"

	gformtab, xlsx("${DATA_DIR}/_test_integration_cde.xlsx") ///
		sheet("With CDE") ///
		title("Table 3. Mediation with Controlled Direct Effect")

	confirm file "${DATA_DIR}/_test_integration_cde.xlsx"
	display as result "  PASSED: gformula with CDE → gformtab"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 4: e() results persist after gformtab
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': e() persists after gformtab"
display as text "{hline 50}"

capture noisily {
	* gformtab is rclass — should NOT clear e()
	* e() should still have gformula results from TEST 3
	assert "`e(cmd)'" == "gformula"
	assert "`e(analysis_type)'" == "mediation"
	confirm scalar e(tce)
	confirm matrix e(b)

	display as result "  PASSED: e() results persist after gformtab call"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 5: estimates store works (eclass proof)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': estimates store works"
display as text "{hline 50}"

capture noisily {
	* Run gformula
	gformula y m x c, outcome(y) mediation obe ///
		exposure(x) mediator(m) ///
		commands(m: logit, y: logit) ///
		equations(m: x c, y: m x c) ///
		base_confs(c) sim(500) samples(50) seed(1)

	* Store estimates (only works for eclass)
	estimates store gf_obe

	* Verify we can recall
	estimates restore gf_obe
	assert "`e(cmd)'" == "gformula"
	confirm scalar e(tce)
	confirm matrix e(b)

	estimates drop gf_obe

	display as result "  PASSED: estimates store/restore works"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 6: No global matrix pollution
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No leaked global matrices"
display as text "{hline 50}"

capture noisily {
	local _leaked = 0
	foreach _mat in _po _se_po _b_msm _se_msm ci_normal ci_percentile ci_bc ci_bca {
		capture confirm matrix `_mat'
		if _rc == 0 {
			display as error "  LEAKED: `_mat'"
			local ++_leaked
		}
	}
	assert `_leaked' == 0
	display as result "  PASSED: No global matrix pollution"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 7: check_xlsx.py validation - normal CI table
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': check_xlsx.py validation (normal CI)"
display as text "{hline 50}"

capture noisily {
	* Validate structure, headers, formatting, and content
	shell python3 "${TOOLS_DIR}/check_xlsx.py" ///
		"${DATA_DIR}/_test_integration_normal.xlsx" ///
		--sheet "Mediation OBE" ///
		--min-rows 7 --max-rows 7 --min-cols 5 --max-cols 5 ///
		--header-row 2 Effect Estimate "95% CI" SE ///
		--bold-row 2 ///
		--merged-row 1 ///
		--has-borders ///
		--font Arial --fontsize 10 ///
		--has-pattern ci ///
		--cell-not-empty B3 C3 D3 E3 B4 C4 D4 E4 B5 C5 D5 E5 B6 C6 D6 E6 ///
		--result-file "${DATA_DIR}/_check_normal.txt"

	* Read result
	file open _fh using "${DATA_DIR}/_check_normal.txt", read text
	file read _fh _line
	file close _fh
	assert "`_line'" == "PASS"
	display as result "  PASSED: check_xlsx.py validated normal CI table"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 8: check_xlsx.py validation - CDE table (7 rows with CDE)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': check_xlsx.py validation (CDE table)"
display as text "{hline 50}"

capture noisily {
	shell python3 "${TOOLS_DIR}/check_xlsx.py" ///
		"${DATA_DIR}/_test_integration_cde.xlsx" ///
		--sheet "With CDE" ///
		--min-rows 7 --max-rows 7 --min-cols 5 --max-cols 5 ///
		--cell-not-empty B7 C7 D7 E7 ///
		--has-borders ///
		--has-pattern ci ///
		--result-file "${DATA_DIR}/_check_cde.txt"

	file open _fh using "${DATA_DIR}/_check_cde.txt", read text
	file read _fh _line
	file close _fh
	assert "`_line'" == "PASS"
	display as result "  PASSED: check_xlsx.py validated CDE table"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 9: check_xlsx.py validation - percentile CI table
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': check_xlsx.py validation (percentile CI)"
display as text "{hline 50}"

capture noisily {
	shell python3 "${TOOLS_DIR}/check_xlsx.py" ///
		"${DATA_DIR}/_test_integration_pctile.xlsx" ///
		--sheet "Percentile" ///
		--min-rows 7 --max-rows 7 ///
		--header-row 2 Effect Estimate "95% CI" SE ///
		--has-borders ///
		--has-pattern ci ///
		--result-file "${DATA_DIR}/_check_pctile.txt"

	file open _fh using "${DATA_DIR}/_check_pctile.txt", read text
	file read _fh _line
	file close _fh
	assert "`_line'" == "PASS"
	display as result "  PASSED: check_xlsx.py validated percentile CI table"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* TEST 10: gformtab error when e() is from wrong command
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gformtab rejects non-gformula e()"
display as text "{hline 50}"

capture noisily {
	* Run a regression to replace e()
	quietly regress y x m c
	assert "`e(cmd)'" == "regress"

	capture gformtab, xlsx("${DATA_DIR}/_test_should_not_exist.xlsx") sheet("Error")
	assert _rc == 119

	display as result "  PASSED: gformtab rejects non-gformula e() results"
	local ++pass_count
}
if _rc {
	display as error "  FAILED: Error code " _rc
	local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

foreach f in _test_integration_normal _test_integration_pctile _test_integration_cde {
	capture erase "${DATA_DIR}/`f'.xlsx"
}
capture erase "${DATA_DIR}/_check_normal.txt"
capture erase "${DATA_DIR}/_check_cde.txt"
capture erase "${DATA_DIR}/_check_pctile.txt"
capture erase "${DATA_DIR}/_test_should_not_exist.xlsx"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "GFORMULA + GFORMTAB INTEGRATION TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
	display as error "Failed:       `fail_count'"
}
else {
	display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
	display as error "Some tests FAILED. Review output above."
	log close inttest
	exit 1
}
else {
	display as result "All tests PASSED!"
}

log close inttest
