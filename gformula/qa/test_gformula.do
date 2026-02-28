* test_gformula.do - Phase 1 verification tests for gformula refactoring
* Tests: load, basic mediation, bug regressions, no globals
* Run: stata-mp -b do ../../_devkit/_testing/test_gformula.do

clear all
set more off

capture log close _all
log using "../../_devkit/_testing/test_gformula.log", replace name(gftest)

local failures = 0
local tests = 0

* ============================================================
* TEST 1: File loads without error
* ============================================================
local ++tests
capture program drop gformula
capture program drop _gformula_bootstrap
capture program drop _gformula_detangle
capture program drop _gformula_formatline
capture run "gformula/gformula.ado"
if _rc != 0 {
	display as error "TEST 1 FAILED: gformula.ado failed to load (rc=`=_rc')"
	local ++failures
}
else {
	display as text "TEST 1 PASSED: gformula.ado loads without error"
}

* ============================================================
* TEST 2: Programs exist after loading
* ============================================================
local ++tests
capture program list gformula
local rc1 = _rc
capture program list _gformula_bootstrap
local rc2 = _rc
capture program list _gformula_detangle
local rc3 = _rc
capture program list _gformula_formatline
local rc4 = _rc
if `rc1' != 0 | `rc2' != 0 | `rc3' != 0 | `rc4' != 0 {
	display as error "TEST 2 FAILED: Not all programs defined (gformula=`rc1' bootstrap=`rc2' detangle=`rc3' formatline=`rc4')"
	local ++failures
}
else {
	display as text "TEST 2 PASSED: All 4 programs defined"
}

* ============================================================
* TEST 3: _gformula_detangle works (replaces SSC detangle)
* ============================================================
local ++tests
clear
set obs 10
gen double y = rbinomial(1, 0.3)
gen double m = rbinomial(1, 0.5)
gen double x = rbinomial(1, 0.4)
gen double c = rnormal()
capture _gformula_detangle "m: logit, y: logit" command "m y"
local det_rc = _rc
if `det_rc' != 0 {
	display as error "TEST 3 FAILED: _gformula_detangle failed (rc=`det_rc')"
	local ++failures
}
else {
	if "${S_1}" != "logit" | "${S_2}" != "logit" {
		display as error "TEST 3 FAILED: _gformula_detangle wrong results (S_1=${S_1} S_2=${S_2})"
		local ++failures
	}
	else {
		display as text "TEST 3 PASSED: _gformula_detangle works correctly"
	}
}

* ============================================================
* TEST 4: _gformula_formatline works (replaces SSC formatline)
* ============================================================
local ++tests
capture _gformula_formatline, n("x c m y some_long_variable another") maxlen(20)
local fmt_rc = _rc
if `fmt_rc' != 0 {
	display as error "TEST 4 FAILED: _gformula_formatline failed (rc=`fmt_rc')"
	local ++failures
}
else {
	if r(lines) < 1 {
		display as error "TEST 4 FAILED: _gformula_formatline returned 0 lines"
		local ++failures
	}
	else {
		display as text "TEST 4 PASSED: _gformula_formatline works correctly (`=r(lines)' lines)"
	}
}

* ============================================================
* TEST 5: Basic mediation analysis runs (obe mode)
* ============================================================
local ++tests
clear
set seed 12345
set obs 500
gen double y = rbinomial(1, 0.3)
gen double m = rbinomial(1, 0.5)
gen double x = rbinomial(1, 0.5)
gen double c = rnormal()

* Record globals before
local globals_before : all globals

capture noisily gformula y m x c, outcome(y) mediation obe ///
	exposure(x) mediator(m) ///
	commands(m: logit, y: logit) ///
	equations(m: x c, y: m x c) ///
	base_confs(c) sim(100) samples(5) seed(1)
local gf_rc = _rc

if `gf_rc' != 0 {
	display as error "TEST 5 FAILED: gformula mediation failed (rc=`gf_rc')"
	local ++failures
}
else {
	display as text "TEST 5 PASSED: gformula mediation analysis completed"
}

* ============================================================
* TEST 6: e() stored results exist (eclass interface)
* ============================================================
local ++tests
if `gf_rc' == 0 {
	local has_tce = 0
	local has_nde = 0
	local has_nie = 0
	local has_pm = 0
	capture confirm scalar e(tce)
	if _rc == 0 local has_tce = 1
	capture confirm scalar e(nde)
	if _rc == 0 local has_nde = 1
	capture confirm scalar e(nie)
	if _rc == 0 local has_nie = 1
	capture confirm scalar e(pm)
	if _rc == 0 local has_pm = 1

	if `has_tce' & `has_nde' & `has_nie' & `has_pm' {
		display as text "TEST 6 PASSED: e(tce)=`=e(tce)' e(nde)=`=e(nde)' e(nie)=`=e(nie)' e(pm)=`=e(pm)'"

		capture confirm scalar e(se_tce)
		local has_se = (_rc == 0)
		capture confirm matrix e(ci_normal)
		local has_ci = (_rc == 0)
		display as text "  e(se_tce) exists: `has_se', e(ci_normal) exists: `has_ci'"
	}
	else {
		display as error "TEST 6 FAILED: Missing e() scalars (tce=`has_tce' nde=`has_nde' nie=`has_nie' pm=`has_pm')"
		local ++failures
	}
}
else {
	display as error "TEST 6 SKIPPED: gformula did not run"
	local ++failures
}

* ============================================================
* TEST 6b: e(cmd) and e(analysis_type) set correctly
* ============================================================
local ++tests
if `gf_rc' == 0 {
	local _pass = 1
	if "`e(cmd)'" != "gformula" {
		display as error "TEST 6b FAILED: e(cmd)='`e(cmd)'', expected 'gformula'"
		local _pass = 0
	}
	if "`e(analysis_type)'" != "mediation" {
		display as error "TEST 6b FAILED: e(analysis_type)='`e(analysis_type)'', expected 'mediation'"
		local _pass = 0
	}
	if `_pass' {
		display as text "TEST 6b PASSED: e(cmd)=gformula, e(analysis_type)=mediation"
	}
	else {
		local ++failures
	}
}
else {
	display as error "TEST 6b SKIPPED: gformula did not run"
	local ++failures
}

* ============================================================
* TEST 6c: e(b) has named columns, e(V) is k x k diagonal
* ============================================================
local ++tests
if `gf_rc' == 0 {
	local _pass = 1
	capture confirm matrix e(b)
	if _rc != 0 {
		display as error "TEST 6c FAILED: e(b) not found"
		local _pass = 0
	}
	else {
		tempname _eb _eV
		matrix `_eb' = e(b)
		local _colnames : colnames `_eb'
		local _first : word 1 of `_colnames'
		if "`_first'" != "tce" {
			display as error "TEST 6c FAILED: e(b) first column='`_first'', expected 'tce'"
			local _pass = 0
		}
		capture confirm matrix e(V)
		if _rc != 0 {
			display as error "TEST 6c FAILED: e(V) not found"
			local _pass = 0
		}
		else {
			matrix `_eV' = e(V)
			local _k = colsof(`_eb')
			if rowsof(`_eV') != `_k' | colsof(`_eV') != `_k' {
				display as error "TEST 6c FAILED: e(V) dimensions wrong"
				local _pass = 0
			}
		}
	}
	if `_pass' {
		display as text "TEST 6c PASSED: e(b) named, e(V) is `_k' x `_k'"
	}
	else {
		local ++failures
	}
}
else {
	display as error "TEST 6c SKIPPED: gformula did not run"
	local ++failures
}

* ============================================================
* TEST 6d: No leaked global matrices
* ============================================================
local ++tests
if `gf_rc' == 0 {
	local _leaked = 0
	capture confirm matrix _po
	if _rc == 0 {
		display as error "  LEAKED: _po global matrix"
		local ++_leaked
	}
	capture confirm matrix _se_po
	if _rc == 0 {
		display as error "  LEAKED: _se_po global matrix"
		local ++_leaked
	}
	capture confirm matrix _b_msm
	if _rc == 0 {
		display as error "  LEAKED: _b_msm global matrix"
		local ++_leaked
	}
	capture confirm matrix _se_msm
	if _rc == 0 {
		display as error "  LEAKED: _se_msm global matrix"
		local ++_leaked
	}
	if `_leaked' > 0 {
		display as error "TEST 6d FAILED: `_leaked' global matrices leaked"
		local ++failures
	}
	else {
		display as text "TEST 6d PASSED: No leaked global matrices"
	}
}
else {
	display as error "TEST 6d SKIPPED: gformula did not run"
	local ++failures
}

* ============================================================
* TEST 7: No global macro pollution (Bug #3 regression)
* ============================================================
local ++tests
local globals_after : all globals

* Check specific globals that were leaked by SSC version
local leaked = 0
capture confirm existence ${maxid}
if _rc == 0 {
	display as error "  LEAKED: $" "maxid"
	local ++leaked
}
capture confirm existence ${check_delete}
if _rc == 0 {
	display as error "  LEAKED: $" "check_delete"
	local ++leaked
}
capture confirm existence ${check_print}
if _rc == 0 {
	display as error "  LEAKED: $" "check_print"
	local ++leaked
}
capture confirm existence ${check_save}
if _rc == 0 {
	display as error "  LEAKED: $" "check_save"
	local ++leaked
}
capture confirm existence ${almost_varlist}
if _rc == 0 {
	display as error "  LEAKED: $" "almost_varlist"
	local ++leaked
}

if `leaked' > 0 {
	display as error "TEST 7 FAILED: `leaked' global macros leaked"
	local ++failures
}
else {
	display as text "TEST 7 PASSED: No global macro pollution"
}

* ============================================================
* TEST 8: No deprecated uniform() in source
* ============================================================
local ++tests
* Use filefilter to count bare uniform() (not runiform())
* First strip all runiform() so they don't false-positive
tempfile temp1 temp2
copy "gformula/gformula.ado" `temp1', replace
filefilter `temp1' `temp2', from("runiform()") to("SAFE_FUNC")
* Now count remaining bare uniform()
filefilter `temp2' `temp1', from("uniform()") to("FOUND_IT") replace
local found_uniform = r(occurrences)

if `found_uniform' > 0 {
	display as error "TEST 8 FAILED: Found `found_uniform' occurrences of bare uniform()"
	local ++failures
}
else {
	display as text "TEST 8 PASSED: No deprecated uniform() in source code"
}

* ============================================================
* TEST 9: Bug #2 regression - oce without baseline() auto-detects
* ============================================================
local ++tests
clear
set seed 54321
set obs 500
gen double y = rbinomial(1, 0.3)
gen double m = rbinomial(1, 0.5)
gen double x = floor(runiform() * 3)
gen double c = rnormal()

capture noisily gformula y m x c, outcome(y) mediation oce ///
	exposure(x) mediator(m) ///
	commands(m: logit, y: logit) ///
	equations(m: x c, y: m x c) ///
	base_confs(c) sim(100) samples(10) seed(1)
local oce_rc = _rc

if `oce_rc' != 0 {
	display as error "TEST 9 FAILED: oce without baseline() failed (rc=`oce_rc')"
	local ++failures
}
else {
	display as text "TEST 9 PASSED: oce without baseline() auto-detects correctly"
}

* ============================================================
* SUMMARY
* ============================================================
display _newline
display as text "=========================================="
display as text "TEST SUMMARY: `=`tests'-`failures''/`tests' passed"
if `failures' > 0 {
	display as error "`failures' FAILURES"
	exit 1
}
else {
	display as result "ALL TESTS PASSED"
}
display as text "=========================================="

log close gftest
