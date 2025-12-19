/*******************************************************************************
* test_effecttab.do
*
* Purpose: Comprehensive testing of effecttab command
*          Tests all options with teffects and margins results
*
* Prerequisites:
*   - effecttab.ado must be installed/accessible
*   - Stata 17+ required for collect commands
*
* Author: Timothy P Copeland
* Date: 2025-12-19
*******************************************************************************/

clear all
set more off
version 17.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    global STATA_TOOLS_PATH "/home/ubuntu/Stata-Tools"
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* =============================================================================
* SETUP: Install package from local repository
* =============================================================================

* Install regtab package (includes effecttab)
capture net uninstall regtab
net install regtab, from("${STATA_TOOLS_PATH}/regtab")

local testdir "${DATA_DIR}"

display as text _n "{hline 70}"
display as text "EFFECTTAB COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* CREATE SYNTHETIC DATA FOR CAUSAL INFERENCE TESTING
* =============================================================================
* We need data with:
* - Binary treatment with good overlap (no perfect prediction)
* - Binary and continuous outcomes
* - Confounders that affect both treatment and outcome
* - Sufficient sample size for stable estimates

display as text _n "Creating synthetic causal inference dataset..."

clear
set seed 54321
set obs 2000

* Confounders
gen age = 30 + runiform() * 40
gen female = runiform() < 0.55
gen education = 1 + floor(runiform() * 4)

* Treatment assignment (depends on confounders, ~50% treated)
gen propensity = invlogit(-1.5 + 0.02*age + 0.3*female + 0.1*education)
gen treatment = runiform() < propensity

* Binary outcome (affected by treatment and confounders)
gen prob_outcome = invlogit(-2 + 0.5*treatment + 0.01*age - 0.2*female + 0.05*education)
gen outcome_bin = runiform() < prob_outcome

* Continuous outcome (affected by treatment and confounders)
gen outcome_cont = 50 + 5*treatment + 0.2*age - 2*female + runiform()*10

* Categorical treatment for multi-level comparisons
gen treat3 = 0 if runiform() < 0.33
replace treat3 = 1 if missing(treat3) & runiform() < 0.5
replace treat3 = 2 if missing(treat3)
label define treat3_lbl 0 "Control" 1 "Low dose" 2 "High dose"
label values treat3 treat3_lbl

* Multi-level outcome probability
gen prob3 = invlogit(-2 + 0.3*(treat3==1) + 0.6*(treat3==2) + 0.01*age)
gen outcome3 = runiform() < prob3

* Survival-like time variable
gen time = 1 + runiform() * 10
gen event = runiform() < (0.3 + 0.1*treatment)

* Labels for cleaner output
label variable age "Age (years)"
label variable female "Female sex"
label variable education "Education level"
label variable treatment "Treatment (binary)"
label variable outcome_bin "Binary outcome"
label variable outcome_cont "Continuous outcome"

save "`testdir'/_effecttab_testdata.dta", replace

display as text "  Created synthetic causal inference dataset: 2000 observations"

* =============================================================================
* TEST 1: Basic teffects ipw - ATE
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': teffects ipw - basic ATE"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female education), ate

    effecttab, xlsx("`testdir'/_test_effecttab.xlsx") sheet("ATE") effect("ATE")

    confirm file "`testdir'/_test_effecttab.xlsx"
    display as result "  PASSED: Basic teffects ipw works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: teffects ipw with title and clean option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': teffects ipw with title and clean"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate

    effecttab, xlsx("`testdir'/_test_effecttab_title.xlsx") sheet("Table 1") ///
        effect("ATE") title("Table 1. Average Treatment Effect (IPTW)") clean

    confirm file "`testdir'/_test_effecttab_title.xlsx"
    display as result "  PASSED: Title and clean options work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: teffects ipw - ATET
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': teffects ipw - ATET"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female education), atet

    effecttab, xlsx("`testdir'/_test_effecttab_atet.xlsx") sheet("ATET") ///
        effect("ATET") title("Average Treatment Effect on Treated")

    confirm file "`testdir'/_test_effecttab_atet.xlsx"
    display as result "  PASSED: ATET estimation works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: teffects ipw - potential outcome means
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': teffects ipw - PO means"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), pomeans

    effecttab, xlsx("`testdir'/_test_effecttab_pomeans.xlsx") sheet("PO Means") ///
        effect("Pr(Y)") title("Potential Outcome Means") clean

    confirm file "`testdir'/_test_effecttab_pomeans.xlsx"
    display as result "  PASSED: PO means works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: teffects ra (regression adjustment / g-computation)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': teffects ra - regression adjustment"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ra (outcome_bin age female education) (treatment), ate

    effecttab, xlsx("`testdir'/_test_effecttab_ra.xlsx") sheet("RA") ///
        effect("ATE") title("G-computation / Regression Adjustment")

    confirm file "`testdir'/_test_effecttab_ra.xlsx"
    display as result "  PASSED: teffects ra works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: teffects aipw (doubly robust)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': teffects aipw - doubly robust"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects aipw (outcome_bin age female) (treatment age female), ate

    effecttab, xlsx("`testdir'/_test_effecttab_aipw.xlsx") sheet("AIPW") ///
        effect("ATE") title("Doubly Robust Estimation") clean

    confirm file "`testdir'/_test_effecttab_aipw.xlsx"
    display as result "  PASSED: teffects aipw works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Multiple models comparison (IPTW vs AIPW)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple models - IPTW vs AIPW"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    collect: teffects aipw (outcome_bin age female) (treatment age female), ate

    effecttab, xlsx("`testdir'/_test_effecttab_multi.xlsx") sheet("Comparison") ///
        models("IPTW \ AIPW") effect("ATE") clean

    confirm file "`testdir'/_test_effecttab_multi.xlsx"
    display as result "  PASSED: Multiple models comparison works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: margins - predicted probabilities
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': margins - predicted probabilities"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    logit outcome_bin i.treatment age female

    collect clear
    collect: margins treatment

    effecttab, xlsx("`testdir'/_test_effecttab_margins.xlsx") sheet("Predictions") ///
        type(margins) effect("Pr(Y)") title("Predicted Probabilities by Treatment")

    confirm file "`testdir'/_test_effecttab_margins.xlsx"
    display as result "  PASSED: margins predicted probabilities works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: margins - marginal effects (dydx)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': margins - marginal effects (dydx)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    logit outcome_bin i.treatment age female education

    collect clear
    collect: margins, dydx(treatment age female)

    effecttab, xlsx("`testdir'/_test_effecttab_dydx.xlsx") sheet("AME") ///
        effect("AME") title("Average Marginal Effects")

    confirm file "`testdir'/_test_effecttab_dydx.xlsx"
    display as result "  PASSED: margins dydx works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: margins - contrasts (risk differences)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': margins - contrasts (risk differences)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    logit outcome_bin i.treatment age female

    collect clear
    collect: margins r.treatment

    effecttab, xlsx("`testdir'/_test_effecttab_contrast.xlsx") sheet("RD") ///
        effect("RD") title("Risk Difference (Treatment vs Control)")

    confirm file "`testdir'/_test_effecttab_contrast.xlsx"
    display as result "  PASSED: margins contrasts works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: margins with at() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': margins with at() specification"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    logit outcome_bin i.treatment age female

    collect clear
    collect: margins treatment, at(age=(30 40 50 60))

    effecttab, xlsx("`testdir'/_test_effecttab_at.xlsx") sheet("By Age") ///
        type(margins) effect("Pr(Y)") title("Predicted Probability at Specific Ages")

    confirm file "`testdir'/_test_effecttab_at.xlsx"
    display as result "  PASSED: margins at() works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Multi-level treatment (3 categories)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multi-level treatment comparisons"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome3) (treat3 age female), ate

    effecttab, xlsx("`testdir'/_test_effecttab_multi3.xlsx") sheet("Multi-level") ///
        effect("ATE") title("Multi-level Treatment Effects") clean

    confirm file "`testdir'/_test_effecttab_multi3.xlsx"
    display as result "  PASSED: Multi-level treatment works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Continuous outcome (linear regression adjustment)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Continuous outcome - linear RA"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ra (outcome_cont age female) (treatment), ate

    effecttab, xlsx("`testdir'/_test_effecttab_cont.xlsx") sheet("Continuous") ///
        effect("ATE") title("Average Treatment Effect (Continuous Outcome)")

    confirm file "`testdir'/_test_effecttab_cont.xlsx"
    display as result "  PASSED: Continuous outcome works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Custom CI separator
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom CI separator"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate

    effecttab, xlsx("`testdir'/_test_effecttab_sep.xlsx") sheet("Custom Sep") ///
        effect("ATE") sep(" to ")

    confirm file "`testdir'/_test_effecttab_sep.xlsx"
    display as result "  PASSED: Custom separator works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Auto-detection of type
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Auto-detection of result type"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    * teffects should auto-detect
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate

    effecttab, xlsx("`testdir'/_test_effecttab_auto.xlsx") sheet("Auto") ///
        effect("Effect")

    confirm file "`testdir'/_test_effecttab_auto.xlsx"
    display as result "  PASSED: Auto-detection works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: Error handling - no collect table
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - no collect"
display as text "{hline 50}"

capture noisily {
    collect clear

    * This should fail with appropriate error
    capture effecttab, xlsx("`testdir'/_test_error.xlsx") sheet("Error")

    if _rc != 0 {
        display as result "  PASSED: Proper error when no collect table"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored without collect table"
        local ++fail_count
    }
}

* =============================================================================
* TEST 17: Error handling - invalid file extension
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Error handling - invalid extension"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_effecttab_testdata.dta", clear

    collect clear
    collect: teffects ipw (outcome_bin) (treatment age), ate

    * This should fail - no .xlsx extension
    capture effecttab, xlsx("`testdir'/_test_error.xls") sheet("Error")

    if _rc != 0 {
        display as result "  PASSED: Proper error for invalid extension"
        local ++pass_count
    }
    else {
        display as error "  FAILED: Should have errored for .xls extension"
        local ++fail_count
    }
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

local output_files "_test_effecttab _test_effecttab_title _test_effecttab_atet _test_effecttab_pomeans _test_effecttab_ra _test_effecttab_aipw _test_effecttab_multi _test_effecttab_margins _test_effecttab_dydx _test_effecttab_contrast _test_effecttab_at _test_effecttab_multi3 _test_effecttab_cont _test_effecttab_sep _test_effecttab_auto"
foreach f of local output_files {
    capture erase "`testdir'/`f'.xlsx"
}

* Clean up test data
capture erase "`testdir'/_effecttab_testdata.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "EFFECTTAB TEST SUMMARY"
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
    exit 1
}
else {
    display as result "All tests PASSED!"
}
