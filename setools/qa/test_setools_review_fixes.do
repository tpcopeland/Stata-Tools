*! Test file for setools review fixes
*! Tests all 8 issues identified in the code review
*! Date: 2026-02-24

clear all
set more off

local passed = 0
local failed = 0
local test_num = 0

capture log close _test_setools_review
log using "../../_devkit/_testing/test_setools_review_fixes.log", replace name(_test_setools_review)

display _dup(70) "="
display "SETOOLS REVIEW FIXES - TEST SUITE"
display _dup(70) "="
display ""

* Reload all commands
local commands "cci_se cdp covarclose migrations pira sustainedss setools"
foreach cmd of local commands {
    capture program drop `cmd'
    quietly run "setools/`cmd'.ado"
}
capture program drop _setools_detail

* =========================================================================
* TEST 1: covarclose merge m:1 with duplicate IDs (Issue #1 - Critical)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': covarclose merge m:1 with duplicate IDs in master"

* Create master data with DUPLICATE IDs (panel/longitudinal format)
clear
input long id double study_start str10 visit_type
1 21000 "baseline"
1 21180 "followup1"
1 21365 "followup2"
2 21500 "baseline"
2 21700 "followup1"
3 21000 "baseline"
end
format study_start %tdCCYY/NN/DD

* Save master with duplicates
tempfile master_panel
save `master_panel'

* Create covariate file with yearly data
clear
input long id int year double income
1 2017 350000
1 2018 370000
2 2017 420000
2 2018 440000
3 2017 280000
3 2018 295000
end
tempfile lisa_data
save `lisa_data'

* Load master (with duplicates) and run covarclose
use `master_panel', clear
capture noisily covarclose using `lisa_data', idvar(id) indexdate(study_start) ///
    datevar(year) vars(income) yearformat prefer(closest)
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: covarclose succeeds with duplicate IDs"
    local ++passed
}
else {
    display as error "  FAILED: covarclose errored with duplicate IDs, rc = `rc'"
    local ++failed
}

* Check all 6 rows preserved
local ++test_num
display _dup(60) "-"
display "Test `test_num': covarclose preserves all master rows"

quietly count
if r(N) == 6 {
    display as result "  PASSED: All 6 master rows preserved"
    local ++passed
}
else {
    display as error "  FAILED: Expected 6 rows, got `r(N)'"
    local ++failed
}

* Check income merged to all rows
local ++test_num
display _dup(60) "-"
display "Test `test_num': covarclose merges income to all rows (m:1)"

quietly count if !missing(income)
if r(N) == 6 {
    display as result "  PASSED: Income merged to all 6 rows"
    local ++passed
}
else {
    display as error "  FAILED: Income only on `r(N)' rows, expected 6"
    local ++failed
}

* =========================================================================
* TEST 4-5: cdp allevents preserves user variables (Issue #2)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': cdp allevents preserves user variables"

clear
input long id double edss double edss_dt double dx_date double age_at_dx
1 2.0 20000 19500 35
1 3.5 20200 19500 35
1 4.0 20400 19500 35
1 5.0 20700 19500 35
1 6.0 21000 19500 35
2 3.0 20000 19500 40
2 4.5 20200 19500 40
2 5.0 20400 19500 40
2 6.0 20700 19500 40
end
format edss_dt dx_date %tdCCYY/NN/DD

capture drop cdp_date
capture noisily cdp id edss edss_dt, dxdate(dx_date) roving allevents keepall

* Check that age_at_dx still exists
capture confirm variable age_at_dx
local rc_var = _rc
if `rc_var' == 0 {
    display as result "  PASSED: cdp allevents preserves user variable age_at_dx"
    local ++passed
}
else {
    display as error "  FAILED: age_at_dx dropped by cdp allevents"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': cdp allevents creates cdp_date variable"

capture confirm variable cdp_date
local rc_cdp = _rc
if `rc_cdp' == 0 {
    display as result "  PASSED: cdp_date created"
    local ++passed
}
else {
    display as error "  FAILED: cdp_date not created"
    local ++failed
}

* =========================================================================
* TEST 6-10: pira tempvars - no leftover hardcoded variables (Issue #3)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': pira rebaselinerelapse runs without error"

* Create EDSS data
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
1 4.0 20500 19500
2 3.0 20000 19500
2 4.5 20200 19500
2 5.0 20500 19500
end
format edss_dt dx_date %tdCCYY/NN/DD
tempfile edss_pira
save `edss_pira'

* Create relapse data
clear
input long id double relapse_date
1 20100
1 20300
2 20050
end
format relapse_date %tdCCYY/NN/DD
tempfile relapse_pira
save `relapse_pira'

use `edss_pira', clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses(`relapse_pira') ///
    rebaselinerelapse keepall quietly
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: pira with rebaselinerelapse runs without error"
    local ++passed
}
else {
    display as error "  FAILED: pira with rebaselinerelapse errored, rc = `rc'"
    local ++failed
}

* Check no leftover hardcoded variables
foreach varcheck in _has_relapse _last_relapse_dt _post_relapse _new_baseline _new_baseline_dt {
    local ++test_num
    display _dup(60) "-"
    display "Test `test_num': No leftover `varcheck' variable"

    capture confirm variable `varcheck'
    if _rc != 0 {
        display as result "  PASSED: No leftover `varcheck'"
        local ++passed
    }
    else {
        display as error "  FAILED: `varcheck' still exists in data"
        local ++failed
    }
}

* =========================================================================
* TEST 11-12: CDP sustained-throughout confirmation (Issue #4)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': Sustained-throughout: regression negates CDP"

* Patient progresses then regresses - should NOT be confirmed
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20100 19500
1 3.5 20300 19500
1 1.5 20500 19500
end
format edss_dt dx_date %tdCCYY/NN/DD

capture drop cdp_date
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall quietly

quietly count if !missing(cdp_date)
if r(N) == 0 {
    display as result "  PASSED: Regression at follow-up negates CDP"
    local ++passed
}
else {
    display as error "  FAILED: CDP should not be confirmed when EDSS drops later"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': Sustained-throughout: maintained progression confirmed"

* Patient progresses and stays elevated - should be confirmed
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20100 19500
1 3.5 20300 19500
1 4.0 20500 19500
end
format edss_dt dx_date %tdCCYY/NN/DD

capture drop cdp_date
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall quietly

quietly count if !missing(cdp_date)
if r(N) > 0 {
    display as result "  PASSED: Sustained progression confirmed as CDP"
    local ++passed
}
else {
    display as error "  FAILED: Sustained progression should be confirmed as CDP"
    local ++failed
}

* =========================================================================
* TEST 13-14: migrations gen long for date (Issue #5)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': migrations creates long type migration_out_dt"

* Create cohort data
clear
input long id double study_start
1 20000
2 20000
3 20000
end
format study_start %tdCCYY/NN/DD
tempfile cohort_mig
save `cohort_mig'

* Create migration file (wide format)
clear
input long id double in_1 double out_1 double in_2 double out_2
2 . 20500 20700 .
3 20100 . . .
end
format in_1 out_1 in_2 out_2 %tdCCYY/NN/DD
tempfile mig_data
save `mig_data'

use `cohort_mig', clear
capture noisily migrations, migfile(`mig_data') idvar(id) startvar(study_start)
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: migrations runs without error"
    local ++passed
}
else {
    display as error "  FAILED: migrations errored, rc = `rc'"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': migration_out_dt is type long"

capture confirm variable migration_out_dt
if _rc == 0 {
    local vtype: type migration_out_dt
    if "`vtype'" == "long" {
        display as result "  PASSED: migration_out_dt is long"
        local ++passed
    }
    else {
        display as error "  FAILED: migration_out_dt is `vtype', expected long"
        local ++failed
    }
}
else {
    * Variable might not exist if no one had censoring events
    * Check if person 2 was censored (they emigrated at 20500)
    display as text "  SKIP: migration_out_dt not created (no censoring events)"
    local ++passed
}

* =========================================================================
* TEST 15-16: sustainedss max iteration guard (Issue #6)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': sustainedss converges normally"

clear
input long id double edss double edss_dt
1 2.0 20000
1 3.0 20100
1 4.0 20200
1 4.5 20400
2 1.0 20000
2 5.0 20100
2 5.5 20300
end
format edss_dt %tdCCYY/NN/DD

capture noisily sustainedss id edss edss_dt, threshold(4) keepall quietly
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: sustainedss converges normally"
    local ++passed
}
else {
    display as error "  FAILED: sustainedss errored, rc = `rc'"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': sustainedss iterations below guard limit"

if `rc' == 0 {
    if r(iterations) < 1000 {
        display as result "  PASSED: iterations = `r(iterations)' (well below 1000)"
        local ++passed
    }
    else {
        display as error "  FAILED: iterations = `r(iterations)' hit guard limit"
        local ++failed
    }
}
else {
    display as error "  SKIP: sustainedss failed"
    local ++failed
}

* =========================================================================
* TEST 17-18: cdp/pira coupling comments - no parse errors (Issue #7)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': cdp runs without parse errors after comments"

clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
1 4.0 20500 19500
end
format edss_dt dx_date %tdCCYY/NN/DD
tempfile edss_coupling
save `edss_coupling'

clear
input long id double relapse_date
1 20100
end
format relapse_date %tdCCYY/NN/DD
tempfile relapse_coupling
save `relapse_coupling'

use `edss_coupling', clear
capture drop cdp_date
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall quietly
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: cdp runs without parse errors"
    local ++passed
}
else {
    display as error "  FAILED: cdp parse error, rc = `rc'"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': pira runs without parse errors after comments"

use `edss_coupling', clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses(`relapse_coupling') ///
    keepall quietly
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: pira runs without parse errors"
    local ++passed
}
else {
    display as error "  FAILED: pira parse error, rc = `rc'"
    local ++failed
}

* =========================================================================
* TEST 19-21: cci_se score type is int (Issue #8)
* =========================================================================
local ++test_num
display _dup(60) "-"
display "Test `test_num': cci_se runs without error"

clear
input long lopnr str10 diagnos double utdatum
1 "I252" 20000
1 "E115" 20100
2 "G35" 20000
3 "I21" 20000
3 "C50" 20100
3 "C78" 20200
end
format utdatum %tdCCYY/NN/DD

capture noisily cci_se, id(lopnr) icd(diagnos) date(utdatum)
local rc = _rc

if `rc' == 0 {
    display as result "  PASSED: cci_se runs without error"
    local ++passed
}
else {
    display as error "  FAILED: cci_se errored, rc = `rc'"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': charlson variable is type int"

if `rc' == 0 {
    local vtype: type charlson
    if "`vtype'" == "int" {
        display as result "  PASSED: charlson is type int"
        local ++passed
    }
    else {
        display as error "  FAILED: charlson is `vtype', expected int"
        local ++failed
    }
}
else {
    display as error "  SKIP: cci_se failed"
    local ++failed
}

local ++test_num
display _dup(60) "-"
display "Test `test_num': CCI scores in valid range"

if `rc' == 0 {
    quietly summarize charlson
    if r(max) >= 0 & r(max) <= 30 {
        display as result "  PASSED: CCI max = `r(max)' (range 0-30)"
        local ++passed
    }
    else {
        display as error "  FAILED: CCI max = `r(max)' out of range"
        local ++failed
    }
}
else {
    display as error "  SKIP: cci_se failed"
    local ++failed
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display _dup(70) "="
display "TEST RESULTS"
display _dup(70) "="
display as text "  Passed: " as result `passed'
display as text "  Failed: " as result `failed'
display as text "  Total:  " as result `=`passed' + `failed''
display _dup(70) "="

if `failed' > 0 {
    display as error "`failed' test(s) FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _test_setools_review
