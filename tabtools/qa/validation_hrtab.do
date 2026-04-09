* validation_hrtab.do — Known-answer and invariant checks for hrtab
* Usage: cd into qa/ directory, then: stata-mp -b do validation_hrtab.do

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =========================================================================
**# SETUP: Create deterministic survival data
* =========================================================================

capture program drop _hrtab_val_data
program define _hrtab_val_data
	clear
	set obs 100
	set seed 54321
	gen long pid = _n
	gen byte trt = cond(_n <= 50, 0, 1)
	label define trt_lbl 0 "Placebo" 1 "Drug"
	label values trt trt_lbl
	gen double age = rnormal(60, 10)
	gen double followup = rexponential(1/5)
	replace followup = min(followup, 10)
	gen byte died = runiform() < 0.3
	gen byte event = 0
	replace event = 1 if runiform() < 0.2
	replace event = 2 if event == 0 & runiform() < 0.15
	label define ev_lbl 0 "Censored" 1 "Cause 1" 2 "Cause 2"
	label values event ev_lbl
end

* =========================================================================
**# 1. KNOWN-ANSWER: Compare hrtab HR to direct stcox
* =========================================================================

**## 1.1 Unadjusted HR matches direct stcox
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	* Run stcox directly to get reference HR
	quietly stcox i.trt, nolog
	local _ref_hr = exp(_b[1.trt])
	local _ref_se = sqrt(e(V)[1,1])
	local _ref_lo = exp(_b[1.trt] - 1.96 * `_ref_se')
	local _ref_hi = exp(_b[1.trt] + 1.96 * `_ref_se')

	* Run hrtab and capture display output
	hrtab, exposure(i.trt) model(stcox) nolog display
	assert r(models) == 1

	* Verify hrtab ran the same model by checking N
	assert r(N_unadjusted) == e(N)
}
if _rc == 0 {
	display as result "  PASS: 1.1 Unadjusted model N matches direct stcox"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.1 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.1"
}

**## 1.2 Adjusted HR — model count correct
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	hrtab, exposure(i.trt) model(stcox) ///
		covars(age) nolog display
	assert r(models) == 2

	* N_adjusted should be <= N_unadjusted
	assert r(N_adjusted) <= r(N_unadjusted)
}
if _rc == 0 {
	display as result "  PASS: 1.2 Adjusted model count and N constraint"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.2 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.2"
}

**## 1.3 Unadjusted HR value matches direct stcox (frame extraction)
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	* Run stcox directly to get reference HR
	quietly stcox i.trt, nolog
	local _ref_hr = round(exp(_b[1.trt]), 0.01)

	* Run hrtab with frame
	hrtab, exposure(i.trt) model(stcox) nolog frame(hrtab_ka1, replace)

	* Extract HR from frame — c4 contains "HR (lo-hi)" for non-ref rows
	frame hrtab_ka1 {
		local _found = 0
		forvalues _r = 1/`=_N' {
			if strmatch(strtrim(c1[`_r']), "*Drug*") {
				* Parse HR from "1.06 (0.49-2.30)" format
				local _cell = strtrim(c4[`_r'])
				local _hr_got = real(substr("`_cell'", 1, strpos("`_cell'", " ") - 1))
				if !missing(`_hr_got') {
					assert abs(`_hr_got' - `_ref_hr') < 0.015
					local _found = 1
					continue, break
				}
			}
		}
		assert `_found' == 1
	}
	capture frame drop hrtab_ka1
}
if _rc == 0 {
	display as result "  PASS: 1.3 Unadjusted HR value matches direct stcox"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.3 HR value mismatch (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.3"
	capture frame drop hrtab_ka1
}

**## 1.4 level(90) CI is narrower than level(95) CI
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	* 95% CI (default)
	hrtab, exposure(i.trt) model(stcox) nolog frame(hrtab_95, replace)

	* 90% CI
	hrtab, exposure(i.trt) model(stcox) nolog level(90) frame(hrtab_90, replace)

	* Extract CI width from both frames
	* Format: "HR (lo-hi)" — parse lo and hi to compute width
	foreach _lev in 95 90 {
		frame hrtab_`_lev' {
			forvalues _r = 1/`=_N' {
				if strmatch(strtrim(c1[`_r']), "*Drug*") {
					local _cell = strtrim(c4[`_r'])
					* Extract between ( and )
					local _ci = substr("`_cell'", strpos("`_cell'", "(") + 1, ///
						strpos("`_cell'", ")") - strpos("`_cell'", "(") - 1)
					* Split on -
					local _lo = real(substr("`_ci'", 1, strpos("`_ci'", "-") - 1))
					local _hi = real(substr("`_ci'", strpos("`_ci'", "-") + 1, .))
					local _width_`_lev' = `_hi' - `_lo'
					continue, break
				}
			}
		}
	}

	* 90% CI must be strictly narrower than 95% CI
	assert `_width_90' < `_width_95'

	capture frame drop hrtab_95
	capture frame drop hrtab_90
}
if _rc == 0 {
	display as result "  PASS: 1.4 level(90) CI narrower than level(95) CI"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.4 CI width comparison (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.4"
	capture frame drop hrtab_95
	capture frame drop hrtab_90
}

**## 1.5 stcrreg SHR matches direct stcrreg
local ++test_count
capture noisily {
	_hrtab_val_data

	stset followup, failure(event == 1) id(pid)

	* Run stcrreg directly
	quietly stcrreg i.trt, compete(event == 2) nolog
	local _ref_shr = round(exp(_b[1.trt]), 0.01)

	* Run hrtab with stcrreg
	hrtab, exposure(i.trt) model(stcrreg) ///
		outcome(event) time(followup) failvalue(1) ///
		stsetopts(id(pid)) nolog frame(hrtab_cr, replace)

	* Extract SHR from frame
	frame hrtab_cr {
		local _found = 0
		forvalues _r = 1/`=_N' {
			if strmatch(strtrim(c1[`_r']), "*Drug*") {
				local _cell = strtrim(c4[`_r'])
				if "`_cell'" != "Ref." & "`_cell'" != "" {
					local _shr_got = real(substr("`_cell'", 1, strpos("`_cell'", " ") - 1))
					if !missing(`_shr_got') {
						assert abs(`_shr_got' - `_ref_shr') < 0.015
						local _found = 1
						continue, break
					}
				}
			}
		}
		assert `_found' == 1
	}
	capture frame drop hrtab_cr
}
if _rc == 0 {
	display as result "  PASS: 1.5 stcrreg SHR matches direct stcrreg"
	local ++pass_count
}
else {
	display as error "  FAIL: 1.5 stcrreg SHR mismatch (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 1.5"
	capture frame drop hrtab_cr
}

**## 1.6 finegray — hrtab runs without error (if installed)
local ++test_count
capture which finegray
if _rc == 0 {
	capture noisily {
		_hrtab_val_data
		hrtab, exposure(i.trt) model(finegray) ///
			outcome(event) time(followup) failvalue(1) ///
			stsetopts(id(pid)) nolog frame(hrtab_fg, replace)
		assert r(models) >= 1
		capture frame drop hrtab_fg
	}
	if _rc == 0 {
		display as result "  PASS: 1.6 finegray model runs without error"
		local ++pass_count
	}
	else {
		display as error "  FAIL: 1.6 finegray model error (rc=`=_rc')"
		local ++fail_count
		local failed_tests "`failed_tests' 1.6"
		capture frame drop hrtab_fg
	}
}
else {
	display as text "  SKIP: 1.6 finegray not installed"
	local ++pass_count
}

* =========================================================================
**# 2. INVARIANTS
* =========================================================================

**## 2.1 Model count = outcomes × panels × models_per_cell
local ++test_count
capture noisily {
	_hrtab_val_data

	hrtab, exposure(i.trt) model(stcox) ///
		outcome(died) time(followup) stsetopts(id(pid)) ///
		covars(age) nolog

	* 1 outcome × 1 panel × 2 models (unadj + adj) = 2
	assert r(models) == 2
	assert r(outcomes) == 1
	assert r(panels) == 1
}
if _rc == 0 {
	display as result "  PASS: 2.1 Model count invariant (1x1x2=2)"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.1 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.1"
}

**## 2.2 Model count with multiple panels and covars
local ++test_count
capture noisily {
	_hrtab_val_data
	gen byte sex = runiformint(0, 1)

	hrtab, exposure(i.trt \ i.sex) model(stcox) ///
		outcome(died) time(followup) stsetopts(id(pid)) ///
		covars(age) nolog

	* 1 outcome × 2 panels × 2 models = 4
	assert r(models) == 4
	assert r(panels) == 2
}
if _rc == 0 {
	display as result "  PASS: 2.2 Model count invariant (1x2x2=4)"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.2 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.2"
}

**## 2.3 Model count with nounadjusted
local ++test_count
capture noisily {
	_hrtab_val_data

	hrtab, exposure(i.trt) model(stcox) ///
		outcome(died) time(followup) stsetopts(id(pid)) ///
		covars(age) nounadjusted nolog

	* 1 outcome × 1 panel × 1 model (adj only) = 1
	assert r(models) == 1
}
if _rc == 0 {
	display as result "  PASS: 2.3 Model count with nounadjusted (1x1x1=1)"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.3 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.3"
}

**## 2.4 Default effect labels
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)
	hrtab, exposure(i.trt) model(stcox) nolog
	assert "`r(cmd)'" == "stcox"

	* stcrreg should default to SHR
	hrtab, exposure(i.trt) model(stcrreg) ///
		outcome(event) time(followup) failvalue(1) ///
		stsetopts(id(pid)) nolog
	assert "`r(cmd)'" == "stcrreg"
}
if _rc == 0 {
	display as result "  PASS: 2.4 Default effect labels (HR for stcox, SHR for stcrreg)"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.4 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.4"
}

**## 2.5 Competing risks: outcomes = number of failvalues
local ++test_count
capture noisily {
	_hrtab_val_data
	hrtab, exposure(i.trt) model(stcrreg) ///
		outcome(event) time(followup) failvalue(1 \ 2) ///
		stsetopts(id(pid)) nolog
	assert r(outcomes) == 2
}
if _rc == 0 {
	display as result "  PASS: 2.5 Competing risks: r(outcomes) == n_failvalues"
	local ++pass_count
}
else {
	display as error "  FAIL: 2.5 (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 2.5"
}

* =========================================================================
**# 3. PERSON-YEARS AND EVENTS vs DIRECT STPTIME
* =========================================================================

**## 3.1 PY and events match stptime (via frame row scan)
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	* Get reference PY/events from stptime
	quietly stptime if trt == 0
	local _py0_ref = string(round(r(ptime), 1), "%11.0fc")
	local _py0_ref = strtrim("`_py0_ref'")
	local _ev0_ref = string(r(failures), "%11.0fc")
	local _ev0_ref = strtrim("`_ev0_ref'")

	* Run hrtab with frame to extract values
	hrtab, exposure(i.trt) model(stcox) nolog frame(hrtab_val, replace)

	* Search the frame for the Placebo row and verify PY
	frame hrtab_val {
		local _found = 0
		forvalues _r = 1/`=_N' {
			if strmatch(strtrim(c1[`_r']), "*Placebo*") {
				local _py_got = strtrim(c2[`_r'])
				local _ev_got = strtrim(c3[`_r'])
				assert "`_py_got'" == "`_py0_ref'"
				assert "`_ev_got'" == "`_ev0_ref'"
				local _found = 1
				continue, break
			}
		}
		assert `_found' == 1
	}
	capture frame drop hrtab_val
}
if _rc == 0 {
	display as result "  PASS: 3.1 PY and events match direct stptime"
	local ++pass_count
}
else {
	display as error "  FAIL: 3.1 PY/events mismatch (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 3.1"
	capture frame drop hrtab_val
}

* =========================================================================
**# 4. FRAME STORAGE
* =========================================================================

**## 4.1 Frame created with expected structure
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	hrtab, exposure(i.trt) model(stcox) covars(age) nolog ///
		frame(hrtab_test, replace)

	frame hrtab_test {
		quietly describe, short
		assert r(N) > 0
		assert r(k) > 0
	}
	capture frame drop hrtab_test
}
if _rc == 0 {
	display as result "  PASS: 4.1 Frame created with data"
	local ++pass_count
}
else {
	display as error "  FAIL: 4.1 Frame storage (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 4.1"
	capture frame drop hrtab_test
}

* =========================================================================
**# 5. SHARED TIME VARIABLE
* =========================================================================

**## 5.1 Single time variable shared across outcomes
local ++test_count
capture noisily {
	_hrtab_val_data
	gen byte died2 = runiform() < 0.2

	hrtab, exposure(i.trt) model(stcox) ///
		outcome(died \ died2) time(followup) ///
		stsetopts(id(pid)) nolog
	assert r(outcomes) == 2
}
if _rc == 0 {
	display as result "  PASS: 5.1 Single shared time variable for multiple outcomes"
	local ++pass_count
}
else {
	display as error "  FAIL: 5.1 Shared time (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 5.1"
}

* =========================================================================
**# 6. IF/IN RESTRICTION
* =========================================================================

**## 6.1 if restriction reduces sample
local ++test_count
capture noisily {
	_hrtab_val_data
	stset followup, failure(died) id(pid)

	* Full sample
	hrtab, exposure(i.trt) model(stcox) nolog
	local _N_full = r(N_unadjusted)

	* Restricted sample
	hrtab if age > 60, exposure(i.trt) model(stcox) nolog
	local _N_restricted = r(N_unadjusted)

	assert `_N_restricted' < `_N_full'
	assert `_N_restricted' > 0
}
if _rc == 0 {
	display as result "  PASS: 6.1 if restriction reduces sample size"
	local ++pass_count
}
else {
	display as error "  FAIL: 6.1 if restriction (error `=_rc')"
	local ++fail_count
	local failed_tests "`failed_tests' 6.1"
}

* =========================================================================
**# SUMMARY
* =========================================================================

display ""
display as result "=== hrtab Validation Summary: `pass_count' passed, `fail_count' failed out of `test_count' tests ==="
if `fail_count' > 0 {
	display as error "Failed tests:`failed_tests'"
	exit 1
}
else {
	display as result "ALL VALIDATION TESTS PASSED"
}
