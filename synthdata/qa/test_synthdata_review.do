// =============================================================================
// Test file: test_synthdata_review.do
// Tests for all fixes from the v1.7.3 code review
// =============================================================================
version 16.0
set more off
set varabbrev off

cap program drop synthdata
run "synthdata/synthdata.ado"

local passed = 0
local failed = 0
local total = 0

// =============================================================================
// TEST 1: Basic parametric synthesis works
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 1: Basic parametric synthesis"
di _dup(60) "="

sysuse auto, clear
synthdata price mpg weight, parametric n(200) replace seed(99)

if _N == 200 {
    qui count if !missing(price) & !missing(mpg) & !missing(weight)
    if r(N) == 200 {
        di as txt "  PASS: Parametric synthesis produced 200 complete obs"
        local ++passed
    }
    else {
        di as error "  FAIL: Parametric synthesis has unexpected missing values"
        local ++failed
    }
}
else {
    di as error "  FAIL: Expected 200 obs, got " _N
    local ++failed
}

// =============================================================================
// TEST 2: Smart synthesis works
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 2: Smart synthesis"
di _dup(60) "="

sysuse auto, clear
synthdata price mpg weight foreign, smart n(200) replace seed(42)

if _N == 200 {
    di as txt "  PASS: Smart synthesis produced 200 obs"
    local ++passed
}
else {
    di as error "  FAIL: Expected 200 obs, got " _N
    local ++failed
}

// =============================================================================
// TEST 3: Bootstrap synthesis works
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 3: Bootstrap synthesis"
di _dup(60) "="

sysuse auto, clear
cap synthdata price mpg weight, bootstrap n(200) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: Bootstrap synthesis error rc=" _rc
    local ++failed
}
else if _N == 200 {
    di as txt "  PASS: Bootstrap synthesis produced 200 obs"
    local ++passed
}
else {
    di as error "  FAIL: Expected 200 obs, got " _N
    local ++failed
}

// =============================================================================
// TEST 4: Sequential synthesis works
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 4: Sequential synthesis"
di _dup(60) "="

sysuse auto, clear
cap synthdata price mpg weight, sequential n(200) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: Sequential synthesis error rc=" _rc
    local ++failed
}
else if _N == 200 {
    di as txt "  PASS: Sequential synthesis produced 200 obs"
    local ++passed
}
else {
    di as error "  FAIL: Expected 200 obs, got " _N
    local ++failed
}

// =============================================================================
// TEST 5: Permute method breaks correlations
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 5: Permute method breaks correlations"
di _dup(60) "="

sysuse auto, clear
qui correlate price mpg weight
local orig_corr_pw = r(C)[2,1]

synthdata price mpg weight, permute n(1000) replace seed(12345)

qui correlate price mpg weight
local perm_corr_pw = r(C)[2,1]

if abs(`perm_corr_pw') < abs(`orig_corr_pw') * 0.5 {
    di as txt "  PASS: Correlation reduced from " %5.3f `orig_corr_pw' " to " %5.3f `perm_corr_pw'
    local ++passed
}
else {
    di as error "  FAIL: Permute did not break correlations (" %5.3f `perm_corr_pw' " vs " %5.3f `orig_corr_pw' ")"
    local ++failed
}

// =============================================================================
// TEST 6: Complex synthesis works
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 6: Complex synthesis"
di _dup(60) "="

sysuse auto, clear
cap synthdata price mpg weight foreign, complex n(200) replace seed(42)
if _rc == 0 & _N == 200 {
    di as txt "  PASS: Complex synthesis produced 200 obs"
    local ++passed
}
else {
    di as error "  FAIL: Complex synthesis failed (_rc=" _rc ", N=" _N ")"
    local ++failed
}

// =============================================================================
// TEST 7: Fix #1 - Panel synthesis preserve/restore scope
// Panel data should work without restore errors
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 7: Fix #1 - Panel synthesis"
di _dup(60) "="

clear
set obs 200
gen double id = ceil(_n / 5)
bysort id: gen double time = _n
gen double y = rnormal() + id * 0.1
gen double x = rnormal()

cap synthdata y x, parametric panel(id time) n(200) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: Panel synthesis error rc=" _rc
    local ++failed
}
else {
    // Check that panel structure exists
    cap confirm variable id
    local rc1 = _rc
    cap confirm variable time
    local rc2 = _rc
    if `rc1' == 0 & `rc2' == 0 & _N > 0 {
        di as txt "  PASS: Panel synthesis completed with " _N " obs"
        local ++passed
    }
    else {
        di as error "  FAIL: Panel variables missing after synthesis"
        local ++failed
    }
}

// =============================================================================
// TEST 8: Fix #1 - Panel with preservevar
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 8: Fix #1 - Panel with preservevar"
di _dup(60) "="

clear
set obs 200
gen double id = ceil(_n / 5)
bysort id: gen double time = _n
gen double y = rnormal() + id * 0.1
gen double x = rnormal()
// sex is constant within panel unit
gen double sex = mod(id, 2)

cap synthdata y x sex, parametric panel(id time) preservevar(sex) n(200) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: Panel with preservevar error rc=" _rc
    local ++failed
}
else {
    // Check sex is constant within each id
    tempvar sex_sd
    qui bysort id: egen double `sex_sd' = sd(sex)
    qui su `sex_sd'
    if r(max) == 0 | r(max) == . {
        di as txt "  PASS: Preservevar maintains within-panel constancy"
        local ++passed
    }
    else {
        di as error "  FAIL: Preservevar not constant within panels (max SD=" r(max) ")"
        local ++failed
    }
}

// =============================================================================
// TEST 9: Fix #3 - condcont in multiple() datasets
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 9: Fix #3 - condcont in multiple datasets"
di _dup(60) "="

sysuse auto, clear
tempfile multi_cond
cap synthdata price mpg weight foreign, smart condcont multiple(2) saving(`multi_cond') seed(42)
if _rc == 0 {
    cap confirm file "`multi_cond'_1.dta"
    local rc1 = _rc
    cap confirm file "`multi_cond'_2.dta"
    local rc2 = _rc
    if `rc1' == 0 & `rc2' == 0 {
        di as txt "  PASS: Multiple datasets with condcont created successfully"
        local ++passed
        cap erase "`multi_cond'_1.dta"
        cap erase "`multi_cond'_2.dta"
    }
    else {
        di as error "  FAIL: Multiple dataset files not found"
        local ++failed
    }
}
else {
    di as error "  FAIL: Multiple condcont synthesis failed rc=" _rc
    local ++failed
}

// =============================================================================
// TEST 10: Fix #4 - noextreme 5% buffer enforcement
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 10: Fix #4 - noextreme bounds enforcement"
di _dup(60) "="

sysuse auto, clear
qui su price
local orig_min = r(min)
local orig_max = r(max)

synthdata price mpg, parametric noextreme n(1000) replace seed(42)

qui su price
local range = `orig_max' - `orig_min'
local buffered_min = `orig_min' + 0.05 * `range'
local buffered_max = `orig_max' - 0.05 * `range'

// Allow a small tolerance for edge cases
if r(min) >= `buffered_min' - 1 & r(max) <= `buffered_max' + 1 {
    di as txt "  PASS: Values bounded within buffered range"
    local ++passed
}
else {
    di as error "  FAIL: Values out of bounds: [" r(min) ", " r(max) "] vs [" `buffered_min' ", " `buffered_max' "]"
    local ++failed
}

// =============================================================================
// TEST 11: Fix #5 - var1<var2 constraint swap
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 11: Fix #5 - var<var constraint"
di _dup(60) "="

clear
set obs 200
gen double lo = runiform() * 50
gen double hi = lo + runiform() * 50 + 10

cap synthdata lo hi, parametric constraints("lo<hi") n(200) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: var<var constraint synthesis error rc=" _rc
    local ++failed
}
else {
    qui count if lo >= hi & !missing(lo) & !missing(hi)
    if r(N) == 0 {
        di as txt "  PASS: All obs satisfy lo < hi constraint"
        local ++passed
    }
    else {
        di as error "  FAIL: " r(N) " obs violate lo < hi constraint"
        local ++failed
    }
}

// =============================================================================
// TEST 12: Fix #8 - Global macro cleanup
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 12: Fix #8 - Global macro cleanup"
di _dup(60) "="

// Set some globals that synthdata should clean up
global SYNTHDATA_derived_test "leftover"
global SD_nlog_max_test "leftover"

sysuse auto, clear
synthdata price mpg, smart n(100) replace seed(42)

// Check if globals were cleaned up
if `"$SYNTHDATA_derived_test"' == "" & `"$SD_nlog_max_test"' == "" {
    di as txt "  PASS: Global macros cleaned up"
    local ++passed
}
else {
    di as error "  FAIL: Global macros not cleaned up"
    local ++failed
    // Manual cleanup
    cap macro drop SYNTHDATA_derived_test
    cap macro drop SD_nlog_max_test
}

// =============================================================================
// TEST 13: String variable synthesis
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 13: String variable synthesis"
di _dup(60) "="

sysuse auto, clear
synthdata make price mpg, smart n(100) replace seed(42)

cap confirm string variable make
if _rc == 0 {
    qui count if make != ""
    if r(N) > 0 {
        di as txt "  PASS: String variable synthesized with " r(N) " non-empty values"
        local ++passed
    }
    else {
        di as error "  FAIL: String variable is all empty"
        local ++failed
    }
}
else {
    di as error "  FAIL: String variable not found in output"
    local ++failed
}

// =============================================================================
// TEST 14: Missingness rate preservation
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 14: Missingness rate preservation"
di _dup(60) "="

clear
set obs 1000
set seed 111
gen double x = rnormal()
gen double y = rnormal()
replace x = . if runiform() < 0.20

qui count if missing(x)
local orig_miss_pct = r(N) / _N

synthdata x y, parametric n(1000) replace seed(42)

qui count if missing(x)
local synth_miss_pct = r(N) / _N

if abs(`synth_miss_pct' - `orig_miss_pct') < 0.05 {
    di as txt "  PASS: Missingness rate preserved: " %4.1f `=`synth_miss_pct'*100' "% vs " %4.1f `=`orig_miss_pct'*100' "%"
    local ++passed
}
else {
    di as error "  FAIL: Missingness mismatch: " %4.1f `=`synth_miss_pct'*100' "% vs " %4.1f `=`orig_miss_pct'*100' "%"
    local ++failed
}

// =============================================================================
// TEST 15: Integer detection and rounding
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 15: Integer detection and rounding"
di _dup(60) "="

clear
set obs 100
set seed 222
gen double age = floor(runiform() * 50) + 20
gen double score = runiform() * 100

synthdata age score, parametric n(200) replace seed(42)

qui count if age != floor(age) & !missing(age)
if r(N) == 0 {
    di as txt "  PASS: Integer variable 'age' correctly rounded"
    local ++passed
}
else {
    di as error "  FAIL: Integer variable has " r(N) " non-integer values"
    local ++failed
}

// =============================================================================
// TEST 16: Variable labels preserved
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 16: Variable labels preserved"
di _dup(60) "="

sysuse auto, clear
local orig_label: variable label price
synthdata price mpg weight, parametric n(100) replace seed(42)
local synth_label: variable label price

if `"`synth_label'"' == `"`orig_label'"' {
    di as txt "  PASS: Variable label preserved: `synth_label'"
    local ++passed
}
else {
    di as error "  FAIL: Label changed from '`orig_label'' to '`synth_label''"
    local ++failed
}

// =============================================================================
// TEST 17: ID variable generation
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 17: ID variable generation"
di _dup(60) "="

sysuse auto, clear
cap synthdata price mpg weight, parametric id(make) n(100) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: ID synthesis error rc=" _rc
    local ++failed
}
else {
    qui su make
    if r(min) == 1 & r(max) == 100 {
        di as txt "  PASS: ID variable is sequential 1-100"
        local ++passed
    }
    else {
        di as error "  FAIL: ID variable range unexpected: " r(min) "-" r(max)
        local ++failed
    }
}

// =============================================================================
// TEST 18: Skip variables set to missing
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 18: Skip variables"
di _dup(60) "="

sysuse auto, clear
synthdata price mpg, skip(weight) n(100) replace seed(42)

qui count if missing(weight)
if r(N) == 100 {
    di as txt "  PASS: Skipped variable is all missing"
    local ++passed
}
else {
    di as error "  FAIL: Skipped variable has non-missing values"
    local ++failed
}

// =============================================================================
// TEST 19: Seed reproducibility
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 19: Seed reproducibility"
di _dup(60) "="

sysuse auto, clear
synthdata price mpg, parametric n(100) replace seed(54321)
qui su price, meanonly
local mean1 = r(mean)

sysuse auto, clear
synthdata price mpg, parametric n(100) replace seed(54321)
qui su price, meanonly
local mean2 = r(mean)

if abs(`mean1' - `mean2') < 0.001 {
    di as txt "  PASS: Same seed produces same results (mean=" %9.2f `mean1' ")"
    local ++passed
}
else {
    di as error "  FAIL: Different results with same seed: " `mean1' " vs " `mean2'
    local ++failed
}

// =============================================================================
// TEST 20: Empirical synthesis preserves bounds
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 20: Empirical synthesis preserves bounds"
di _dup(60) "="

sysuse auto, clear
qui su price
local orig_min = r(min)
local orig_max = r(max)

synthdata price mpg, parametric empirical n(500) replace seed(42)

qui su price
if r(min) >= `orig_min' & r(max) <= `orig_max' {
    di as txt "  PASS: Empirical synthesis stays within original bounds"
    local ++passed
}
else {
    di as error "  FAIL: Out of bounds [" r(min) ", " r(max) "] vs [" `orig_min' ", " `orig_max' "]"
    local ++failed
}

// =============================================================================
// TEST 21: Multiple datasets basic
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 21: Multiple datasets"
di _dup(60) "="

sysuse auto, clear
tempfile multi_base
cap synthdata price mpg weight, smart multiple(2) saving(`multi_base') seed(42)
if _rc == 0 {
    cap confirm file "`multi_base'_1.dta"
    local rc1 = _rc
    cap confirm file "`multi_base'_2.dta"
    local rc2 = _rc
    if `rc1' == 0 & `rc2' == 0 {
        di as txt "  PASS: Multiple datasets created successfully"
        local ++passed
        cap erase "`multi_base'_1.dta"
        cap erase "`multi_base'_2.dta"
    }
    else {
        di as error "  FAIL: Multiple dataset files not found"
        local ++failed
    }
}
else {
    di as error "  FAIL: Multiple synthesis failed rc=" _rc
    local ++failed
}

// =============================================================================
// TEST 22: Compare option produces output
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 22: Compare option"
di _dup(60) "="

sysuse auto, clear
cap synthdata price mpg weight, parametric n(200) replace seed(42) compare
if _rc == 0 {
    di as txt "  PASS: Compare option completed without error"
    local ++passed
}
else {
    di as error "  FAIL: Compare option failed rc=" _rc
    local ++failed
}

// =============================================================================
// TEST 23: Fix #6 - Random effects with panel (performance fix)
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 23: Fix #6 - Panel random effects"
di _dup(60) "="

clear
set obs 200
gen double id = ceil(_n / 5)
bysort id: gen double time = _n
gen double y = rnormal() + id * 0.1
gen double x = rnormal()

cap synthdata y x, parametric panel(id time) autocorr(1) n(200) replace seed(42)
if _rc != 0 {
    di as error "  FAIL: Panel with autocorr error rc=" _rc
    local ++failed
}
else if _N > 0 {
    di as txt "  PASS: Panel with autocorr completed (" _N " obs)"
    local ++passed
}
else {
    di as error "  FAIL: No observations produced"
    local ++failed
}

// =============================================================================
// TEST 24: condcat and condcont options distinct
// =============================================================================
local ++total
di _n _dup(60) "="
di "TEST 24: condcat and condcont options"
di _dup(60) "="

sysuse auto, clear
cap synthdata price mpg weight foreign, condcat condcont n(100) replace seed(42)
if _rc == 0 {
    di as txt "  PASS: condcat and condcont parsed without ambiguity"
    local ++passed
}
else {
    di as error "  FAIL: Option parsing error rc=" _rc
    local ++failed
}

// =============================================================================
// SUMMARY
// =============================================================================
di _n _dup(60) "="
di "TEST SUMMARY"
di _dup(60) "="
di as txt "Total tests: " as res `total'
di as txt "Passed:      " as res `passed'
di as txt "Failed:      " as res `failed'
di _dup(60) "="

if `failed' > 0 {
    di as error _n "SOME TESTS FAILED"
    exit 1
}
else {
    di as txt _n "ALL TESTS PASSED"
}
