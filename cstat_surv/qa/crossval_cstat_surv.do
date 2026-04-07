/*******************************************************************************
* crossval_cstat_surv.do
*
* Cross-validation tests for cstat_surv command
* Compares cstat_surv output against:
*   - Manual pair-counting in Stata
*   - estat concordance (built-in Stata)
*   - Internal consistency across datasets
*
* Self-contained: all data generated inline
*
* Author: Timothy P Copeland
* Date: 2026-03-21
*******************************************************************************/

clear all
set more off
version 16.0

* Install from local directory

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall cstat_surv
capture program drop cstat_surv
adopath ++ "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

display as text _n "{hline 70}"
display as text "CSTAT_SURV CROSS-VALIDATION TESTS"
display as text "{hline 70}"

* =============================================================================
* PART A: MANUAL PAIR-COUNTING (N=6)
* =============================================================================
display as text _n "Part A: Manual Pair-Counting"
display as text "{hline 50}"

* CV1: Manual concordance calculation on small dataset
* We create N=6 observations, fit stcox, predict HR, then manually
* count concordant/discordant/tied pairs and compare to cstat_surv
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 5.0
        2 1 4.0
        3 1 3.0
        5 0 2.0
        6 1 1.0
        8 0 0.5
    end
    stset time, failure(event)
    stcox x
    predict double hr, hr

    * Manual pair counting
    * Comparable pairs: (i,j) where min(ti,tj) has an event
    local concordant = 0
    local discordant = 0
    local tied = 0
    local comparable = 0

    forvalues i = 1/6 {
        forvalues j = `=`i'+1'/6 {
            local ti = time[`i']
            local tj = time[`j']
            local ei = event[`i']
            local ej = event[`j']
            local hi = hr[`i']
            local hj = hr[`j']

            if `ti' < `tj' & `ei' == 1 {
                local ++comparable
                if `hi' > `hj' {
                    local ++concordant
                }
                else if `hi' < `hj' {
                    local ++discordant
                }
                else {
                    local ++tied
                }
            }
            else if `tj' < `ti' & `ej' == 1 {
                local ++comparable
                if `hj' > `hi' {
                    local ++concordant
                }
                else if `hj' < `hi' {
                    local ++discordant
                }
                else {
                    local ++tied
                }
            }
            else if `ti' == `tj' & `ei' == 1 & `ej' == 1 {
                local ++comparable
                if `hi' != `hj' {
                    local concordant = `concordant' + 0.5
                    local discordant = `discordant' + 0.5
                }
                else {
                    local ++tied
                }
            }
        }
    }

    local manual_c = (`concordant' + 0.5 * `tied') / `comparable'

    * Now get cstat_surv result
    stcox x
    cstat_surv

    * Compare
    display as text "  Manual: C=`manual_c' comp=`comparable' conc=`concordant' disc=`discordant' tied=`tied'"
    display as text "  cstat_surv: C=" e(c) " comp=" e(N_comparable) " conc=" e(N_concordant) " disc=" e(N_discordant) " tied=" e(N_tied)

    assert abs(e(c) - `manual_c') < 1e-10
    assert abs(e(N_comparable) - `comparable') < 1e-10
    assert abs(e(N_concordant) - `concordant') < 1e-10
    assert abs(e(N_discordant) - `discordant') < 1e-10
    assert abs(e(N_tied) - `tied') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — Manual pair-counting (N=6)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — Manual pair-counting (rc=`=_rc')"
    local ++fail_count
}

* CV2: Manual pair-counting with tied times
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        2 1 6.0
        2 1 3.0
        4 1 5.0
        4 0 2.0
        6 1 1.0
    end
    stset time, failure(event)
    stcox x
    predict double hr2, hr

    local concordant = 0
    local discordant = 0
    local tied = 0
    local comparable = 0

    forvalues i = 1/5 {
        forvalues j = `=`i'+1'/5 {
            local ti = time[`i']
            local tj = time[`j']
            local ei = event[`i']
            local ej = event[`j']
            local hi = hr2[`i']
            local hj = hr2[`j']

            if `ti' < `tj' & `ei' == 1 {
                local ++comparable
                if `hi' > `hj' {
                    local ++concordant
                }
                else if `hi' < `hj' {
                    local ++discordant
                }
                else {
                    local ++tied
                }
            }
            else if `tj' < `ti' & `ej' == 1 {
                local ++comparable
                if `hj' > `hi' {
                    local ++concordant
                }
                else if `hj' < `hi' {
                    local ++discordant
                }
                else {
                    local ++tied
                }
            }
            else if `ti' == `tj' & `ei' == 1 & `ej' == 1 {
                local ++comparable
                if `hi' != `hj' {
                    local concordant = `concordant' + 0.5
                    local discordant = `discordant' + 0.5
                }
                else {
                    local ++tied
                }
            }
        }
    }

    local manual_c = (`concordant' + 0.5 * `tied') / `comparable'

    stcox x
    cstat_surv

    display as text "  Manual: C=`manual_c' comp=`comparable' conc=`concordant' disc=`discordant' tied=`tied'"
    display as text "  cstat_surv: C=" e(c) " comp=" e(N_comparable) " conc=" e(N_concordant) " disc=" e(N_discordant) " tied=" e(N_tied)

    assert abs(e(c) - `manual_c') < 1e-10
    assert abs(e(N_comparable) - `comparable') < 1e-10
    assert abs(e(N_concordant) - `concordant') < 1e-10
    assert abs(e(N_discordant) - `discordant') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — Manual pair-counting with tied times"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — Manual pair-counting with ties (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* PART B: COMPARISON WITH ESTAT CONCORDANCE
* =============================================================================
display as text _n "Part B: Comparison with estat concordance"
display as text "{hline 50}"

* CV3: Compare C-statistic with estat concordance on cancer data
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    estat concordance
    local estat_c = r(C)

    stcox age drug
    cstat_surv
    local our_c = e(c)

    display as text "  estat concordance: C = `estat_c'"
    display as text "  cstat_surv:        C = `our_c'"
    display as text "  difference:        " abs(`our_c' - `estat_c')

    * Should match closely (both compute Harrell's C)
    assert abs(`our_c' - `estat_c') < 0.01
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — vs estat concordance (cancer data)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — vs estat concordance (rc=`=_rc')"
    local ++fail_count
}

* CV4: Compare with estat concordance on synthetic data
local ++test_count
capture noisily {
    clear
    set seed 44044
    set obs 150
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double time = exp(-0.5 * x1 + 0.3 * x2 + rnormal())
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/30
    stset time, failure(event)
    stcox x1 x2
    estat concordance
    local estat_c = r(C)

    stcox x1 x2
    cstat_surv
    local our_c = e(c)

    display as text "  estat concordance: C = `estat_c'"
    display as text "  cstat_surv:        C = `our_c'"
    display as text "  difference:        " abs(`our_c' - `estat_c')

    assert abs(`our_c' - `estat_c') < 0.01
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — vs estat concordance (synthetic)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — vs estat concordance synthetic (rc=`=_rc')"
    local ++fail_count
}

* CV5: Compare with estat concordance — single predictor
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age
    estat concordance
    local estat_c = r(C)

    stcox age
    cstat_surv
    local our_c = e(c)

    display as text "  estat concordance: C = `estat_c'"
    display as text "  cstat_surv:        C = `our_c'"

    assert abs(`our_c' - `estat_c') < 0.01
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — vs estat concordance (single predictor)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — vs estat concordance single (rc=`=_rc')"
    local ++fail_count
}

* CV6: Compare with estat concordance — categorical predictor
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox i.drug age
    estat concordance
    local estat_c = r(C)

    stcox i.drug age
    cstat_surv
    local our_c = e(c)

    display as text "  estat concordance: C = `estat_c'"
    display as text "  cstat_surv:        C = `our_c'"

    assert abs(`our_c' - `estat_c') < 0.01
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — vs estat concordance (categorical)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — vs estat concordance categorical (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* PART C: SOMERS' D = 2C - 1 ACROSS DATASETS
* =============================================================================
display as text _n "Part C: Somers' D = 2C - 1 Across Datasets"
display as text "{hline 50}"

* CV7: Verify Somers' D = 2C - 1 across 5 different datasets
local ++test_count
capture noisily {
    local all_pass = 1
    forvalues ds = 1/5 {
        clear
        set seed `=70070 + `ds' * 111'
        set obs `=40 + `ds' * 20'
        gen double x = rnormal()
        gen double time = exp(-0.3 * `ds' * x + rnormal())
        gen byte event = runiform() > 0.35
        replace event = 1 in 1/`=5 + `ds' * 3'
        stset time, failure(event)
        stcox x
        cstat_surv
        local d_expected = 2 * e(c) - 1
        local d_actual = e(somers_d)
        if abs(`d_actual' - `d_expected') >= 1e-10 {
            display as error "  Dataset `ds': D=`d_actual' expected=`d_expected'"
            local all_pass = 0
        }
    }
    assert `all_pass' == 1
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — Somers' D = 2C-1 across 5 datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — Somers' D across datasets (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* PART D: PAIR COUNTS CONSISTENCY
* =============================================================================
display as text _n "Part D: Pair Counts Consistency"
display as text "{hline 50}"

* CV8: concordant + discordant + tied = comparable across datasets
local ++test_count
capture noisily {
    local all_pass = 1
    forvalues ds = 1/5 {
        clear
        set seed `=80080 + `ds' * 222'
        set obs `=30 + `ds' * 15'
        gen double x = rnormal()
        gen double time = exp(-0.4 * x + rnormal())
        gen byte event = runiform() > 0.4
        replace event = 1 in 1/`=5 + `ds' * 2'
        stset time, failure(event)
        stcox x
        cstat_surv
        local sum_pairs = e(N_concordant) + e(N_discordant) + e(N_tied)
        if abs(e(N_comparable) - `sum_pairs') >= 0.01 {
            display as error "  Dataset `ds': comparable=" e(N_comparable) " sum=" `sum_pairs'
            local all_pass = 0
        }
    }
    assert `all_pass' == 1
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — Pair counts sum correctly across 5 datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — Pair counts sum (rc=`=_rc')"
    local ++fail_count
}

* CV9: C formula = (conc + 0.5*tied) / comparable across datasets
local ++test_count
capture noisily {
    local all_pass = 1
    forvalues ds = 1/5 {
        clear
        set seed `=90090 + `ds' * 333'
        set obs `=50 + `ds' * 10'
        gen double x = rnormal()
        gen double time = exp(-0.5 * x + rnormal() * 0.8)
        gen byte event = runiform() > 0.3
        replace event = 1 in 1/`=8 + `ds' * 3'
        stset time, failure(event)
        stcox x
        cstat_surv
        local c_formula = (e(N_concordant) + 0.5 * e(N_tied)) / e(N_comparable)
        if abs(e(c) - `c_formula') >= 1e-10 {
            display as error "  Dataset `ds': C=" e(c) " formula=`c_formula'"
            local all_pass = 0
        }
    }
    assert `all_pass' == 1
}
if _rc == 0 {
    display as result "  PASS: CV`test_count' — C formula verified across 5 datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: CV`test_count' — C formula (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CSTAT_SURV CROSS-VALIDATION SUMMARY"
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
    display as error "RESULT: FAIL"
    exit 1
}
else {
    display as result "RESULT: PASS"
}
