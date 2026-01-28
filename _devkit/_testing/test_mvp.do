/*******************************************************************************
* test_mvp.do
*
* Purpose: Comprehensive testing of mvp (Missing Value Patterns) command
*          Tests all options documented in mvp.sthlp
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - mvp.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-06
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    * Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
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
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Change to data directory
cd "${DATA_DIR}"

* Install mvp package from local repository
capture net uninstall mvp
net install mvp, from("${STATA_TOOLS_PATH}/mvp") force

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/cohort_miss.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "MVP COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic missing value pattern analysis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic missing value pattern analysis"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking

    * Check stored results
    assert !missing(r(N))
    assert !missing(r(N_vars))
    assert !missing(r(N_patterns))
    display as text "  N observations: " r(N)
    display as text "  N variables: " r(N_vars)
    display as text "  N patterns: " r(N_patterns)
    display as result "  PASSED: Basic pattern analysis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: All variables (implicit)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All variables (no varlist)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp

    display as result "  PASSED: All variables analysis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: notable option (suppress variable table)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': notable option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, notable

    display as result "  PASSED: notable option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: skip option (spaces every 5 variables)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': skip option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, skip

    display as result "  PASSED: skip option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: sort option (sort by descending missingness)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': sort option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, sort

    display as result "  PASSED: sort option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: nodrop option (include vars with no missing)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': nodrop option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi female, nodrop

    display as result "  PASSED: nodrop option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: wide option (compact display)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': wide option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, wide

    display as result "  PASSED: wide option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: nosummary option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': nosummary option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, nosummary

    display as result "  PASSED: nosummary option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: minfreq() option (minimum frequency threshold)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': minfreq() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, minfreq(5)

    display as result "  PASSED: minfreq() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: minmissing() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': minmissing() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, minmissing(2)

    display as result "  PASSED: minmissing() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: maxmissing() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': maxmissing() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, maxmissing(3)

    display as result "  PASSED: maxmissing() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: ascending option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': ascending option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, ascending

    display as result "  PASSED: ascending option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: percent option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': percent option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, percent

    display as result "  PASSED: percent option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: cumulative option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': cumulative option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, percent cumulative

    display as result "  PASSED: cumulative option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: correlate option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': correlate option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, correlate

    * Check correlation matrix is stored
    matrix list r(corr_miss)
    display as result "  PASSED: correlate option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: monotone option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': monotone option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, monotone

    * Check monotone results stored
    display as text "  Monotone status: " r(monotone_status)
    display as text "  N monotone: " r(N_monotone)
    display as text "  Pct monotone: " %5.1f r(pct_monotone) "%"
    display as result "  PASSED: monotone option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: generate() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': generate() option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, generate(m)

    * Check that variables were created
    confirm variable m_age m_education m_bmi m_income_q
    confirm variable m_pattern m_nmiss
    tab m_nmiss
    display as result "  PASSED: generate() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 18: save() option - save to frame
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': save() option - frame"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, save(mvp_patterns)

    * Check frame was created
    frame mvp_patterns: describe, short
    frame drop mvp_patterns
    display as result "  PASSED: save() to frame works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 19: save() option - save to file
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': save() option - file"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, save("`testdir'/_mvp_patterns.dta")

    * Check file was created
    confirm file "`testdir'/_mvp_patterns.dta"
    * Clean up
    erase "`testdir'/_mvp_patterns.dta"
    display as result "  PASSED: save() to file works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 20: graph(bar) option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(bar) option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, graph(bar) nodraw

    display as result "  PASSED: graph(bar) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 21: graph(bar) with sort and vertical
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(bar) with sort and vertical"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(bar) sort vertical barcolor(maroon) nodraw

    display as result "  PASSED: graph(bar) vertical with sort works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 22: graph(patterns) option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(patterns) option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, graph(patterns) nodraw

    display as result "  PASSED: graph(patterns) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 23: graph(patterns) with top()
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(patterns) with top()"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, ///
        graph(patterns) top(10) title("Top 10 Missing Patterns") nodraw

    display as result "  PASSED: graph(patterns) with top() works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 24: graph(matrix) option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(matrix) option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(matrix) nodraw

    display as result "  PASSED: graph(matrix) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 25: graph(matrix) with sample and sort suboptions
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(matrix) with suboptions"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, ///
        graph(matrix, sample(200) sort) ///
        misscolor(red) obscolor(green*0.2) nodraw

    display as result "  PASSED: graph(matrix) with suboptions works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 26: graph(correlation) option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(correlation) option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, graph(correlation) nodraw

    display as result "  PASSED: graph(correlation) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 27: graph(correlation) with textlabels and colorramp
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph(correlation) with options"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, ///
        graph(correlation) textlabels colorramp(grayscale) nodraw

    display as result "  PASSED: graph(correlation) with options works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 28: graph with gname() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph with gname()"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(bar) gname(mvp_test) nodraw

    * Check graph exists in memory
    graph describe mvp_test
    graph drop mvp_test
    display as result "  PASSED: gname() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 29: graph with gsaving() option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph with gsaving()"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, ///
        graph(bar) gsaving("`testdir'/_mvp_graph.gph", replace) nodraw

    * Check file was created
    confirm file "`testdir'/_mvp_graph.gph"
    * Clean up
    erase "`testdir'/_mvp_graph.gph"
    display as result "  PASSED: gsaving() option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 30: graph with scheme() and title()
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': graph with scheme() and title()"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, ///
        graph(bar) scheme(s1mono) ///
        title("Missing Data by Variable") subtitle("Test Data") nodraw

    display as result "  PASSED: scheme() and title() options work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 31: gby() stratification option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gby() stratification"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(bar) gby(female) nodraw

    * Check stored results
    assert "`r(gby)'" == "female"
    display as result "  PASSED: gby() stratification works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 32: over() stratification option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': over() stratification"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(bar) over(female) nodraw

    * Check stored results
    assert "`r(over)'" == "female"
    display as result "  PASSED: over() stratification works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 33: stacked option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': stacked option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(bar) stacked nodraw

    display as result "  PASSED: stacked option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 34: over() with groupgap() and legendopts()
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': over() with groupgap() and legendopts()"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, ///
        graph(bar) over(female) groupgap(20) ///
        legendopts(rows(1) position(6)) nodraw

    display as result "  PASSED: over() with groupgap() and legendopts() works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 35: gby() with graph(patterns)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': gby() with graph(patterns)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q, graph(patterns) gby(female) top(5) nodraw

    display as result "  PASSED: gby() with graph(patterns) works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 36: If condition
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': If condition"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q if female == 1

    display as result "  PASSED: If condition works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 37: In range
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': In range"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q in 1/500

    display as result "  PASSED: In range works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 38: by prefix
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': by prefix"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    bysort female: mvp age education bmi income_q

    display as result "  PASSED: by prefix works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 39: No missing values scenario
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No missing values scenario"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear  // Complete dataset

    * Variables without missing
    mvp female mstype region

    display as result "  PASSED: No missing values scenario handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 40: All missing in one variable
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All missing in one variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    * Create a variable with all missing
    gen all_missing = .

    mvp age all_missing education

    drop all_missing
    display as result "  PASSED: All missing variable handled"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 41: Stored results verification
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results verification"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking

    * Verify all expected stored results exist
    assert !missing(r(N))
    assert !missing(r(N_complete))
    assert !missing(r(N_incomplete))
    assert !missing(r(N_patterns))
    assert !missing(r(N_vars))
    assert !missing(r(max_miss))
    assert !missing(r(mean_miss))
    assert !missing(r(N_mv_total))

    display as result "  PASSED: All stored results present"
    display as text "  r(N) = " r(N)
    display as text "  r(N_complete) = " r(N_complete)
    display as text "  r(N_incomplete) = " r(N_incomplete)
    display as text "  r(N_patterns) = " r(N_patterns)
    display as text "  r(N_vars) = " r(N_vars)
    display as text "  r(max_miss) = " r(max_miss)
    display as text "  r(mean_miss) = " %5.2f r(mean_miss)
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 42: Multiple filtering options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple filtering options combined"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, ///
        minfreq(3) minmissing(1) maxmissing(4) percent cumulative

    display as result "  PASSED: Multiple filtering options work together"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 43: All display options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All display options combined"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort_miss.dta", clear

    mvp age education bmi income_q comorbidity smoking, ///
        sort skip wide percent cumulative

    display as result "  PASSED: All display options work together"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 44: HRT dataset with missingness
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': HRT dataset missingness"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/hrt_miss.dta", clear

    mvp hrt_type dose

    display as result "  PASSED: HRT dataset missingness works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 45: DMT dataset with missingness
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': DMT dataset missingness"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/dmt_miss.dta", clear

    * Note: dmt_miss.dta only has: id, dmt_start, dmt_stop, dmt
    mvp dmt

    display as result "  PASSED: DMT dataset missingness works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MVP TEST SUMMARY"
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
