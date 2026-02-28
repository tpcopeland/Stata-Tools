* test_synthdata_registry.do
* Tests for registry data improvements: row-count matching,
* string distribution preservation, and constant-within-ID enforcement.
* 2026-02-27

clear all
set more off
set varabbrev off

capture ado uninstall synthdata
capture program drop synthdata
capture program drop _synthdata_*
run "synthdata/synthdata.ado"

local test_pass = 0
local test_fail = 0
local test_total = 0

* =========================================================================
* Create test registry dataset
* =========================================================================
* Patients with variable visit counts (1-15), constant demographics,
* time-varying clinical data, and string variables

clear
set seed 12345
set obs 50

* Patient IDs
gen long patient_id = _n

* Assign row counts (skewed: most 1-5, some 6-15)
gen int n_visits = 1 + int(rexponential(3))
replace n_visits = min(n_visits, 15)

* Expand to multi-row
expand n_visits
sort patient_id
bysort patient_id: gen int visit_num = _n

* Constant-within-ID variables (demographics)
bysort patient_id: gen byte sex = cond(_n == 1, rbinomial(1, 0.45), .)
bysort patient_id: replace sex = sex[1]
label define sex_lbl 0 "Female" 1 "Male"
label values sex sex_lbl

bysort patient_id: gen int birth_year = cond(_n == 1, 1940 + int(runiform() * 50), .)
bysort patient_id: replace birth_year = birth_year[1]

* String variable: ethnicity (constant within ID)
gen str20 ethnicity = ""
bysort patient_id: replace ethnicity = cond(runiform() < 0.6, "White", ///
    cond(runiform() < 0.5, "Black", ///
    cond(runiform() < 0.5, "Hispanic", "Asian"))) if _n == 1
bysort patient_id: replace ethnicity = ethnicity[1]

* Time-varying string variable: drug name
gen str20 drug_name = ""
replace drug_name = cond(runiform() < 0.3, "Methotrexate", ///
    cond(runiform() < 0.4, "Rituximab", ///
    cond(runiform() < 0.5, "Fingolimod", "Natalizumab")))

* Time-varying numeric variables
gen double lab_value = rnormal(50, 15)
gen double bp_systolic = rnormal(130, 20)

* Save original stats for comparison
qui count
local orig_n = r(N)
bysort patient_id: gen byte _first = (_n == 1)
qui count if _first == 1
local orig_n_ids = r(N)
drop _first

* Check sex is actually constant within ID
tempvar sex_check
bysort patient_id: gen byte `sex_check' = (sex != sex[1])
qui count if `sex_check' == 1
assert r(N) == 0

* Store original string distribution
preserve
contract ethnicity, freq(orig_freq)
sort ethnicity
tempfile orig_eth_dist
save `orig_eth_dist'
restore

preserve
contract drug_name, freq(orig_freq)
sort drug_name
tempfile orig_drug_dist
save `orig_drug_dist'
restore

* Save for later comparison
tempfile orig_data
save `orig_data'

di _n "Original data: `orig_n' rows, `orig_n_ids' IDs"

* =========================================================================
* TEST 1: Row count matches target
* =========================================================================
local ++test_total
di _n "TEST 1: Row count output matches target"

use `orig_data', clear
synthdata lab_value bp_systolic sex birth_year visit_num ethnicity drug_name, ///
    id(patient_id) smart replace seed(42)

qui count
local synth_n = r(N)
local row_diff = abs(`synth_n' - `orig_n')
local row_pct = (`row_diff' / `orig_n') * 100

di "  Original rows: `orig_n'"
di "  Synthetic rows: `synth_n'"
di "  Difference: `row_diff' (" %4.1f `row_pct' "%)"

* Allow up to 5% drift (was much worse before fix)
if `row_pct' < 5 {
    di as result "  PASS: Row count within 5% of target"
    local ++test_pass
}
else {
    di as error "  FAIL: Row count drifted " %4.1f `row_pct' "% from target"
    local ++test_fail
}

* =========================================================================
* TEST 2: Constant-within-ID variables are actually constant
* =========================================================================
local ++test_total
di _n "TEST 2: sex is constant within synthetic IDs"

tempvar sex_const
bysort patient_id: gen byte `sex_const' = (sex != sex[1])
qui count if `sex_const' == 1
local sex_violations = r(N)

if `sex_violations' == 0 {
    di as result "  PASS: sex is constant within all IDs"
    local ++test_pass
}
else {
    di as error "  FAIL: sex varies within `sex_violations' rows"
    local ++test_fail
}

* =========================================================================
* TEST 3: birth_year is constant within synthetic IDs
* =========================================================================
local ++test_total
di _n "TEST 3: birth_year is constant within synthetic IDs"

tempvar by_const
bysort patient_id: gen byte `by_const' = (birth_year != birth_year[1])
qui count if `by_const' == 1
local by_violations = r(N)

if `by_violations' == 0 {
    di as result "  PASS: birth_year is constant within all IDs"
    local ++test_pass
}
else {
    di as error "  FAIL: birth_year varies within `by_violations' rows"
    local ++test_fail
}

* =========================================================================
* TEST 4: ethnicity (string, constant-within-ID) is constant
* =========================================================================
local ++test_total
di _n "TEST 4: ethnicity is constant within synthetic IDs"

tempvar eth_const
bysort patient_id: gen byte `eth_const' = (ethnicity != ethnicity[1])
qui count if `eth_const' == 1
local eth_violations = r(N)

if `eth_violations' == 0 {
    di as result "  PASS: ethnicity is constant within all IDs"
    local ++test_pass
}
else {
    di as error "  FAIL: ethnicity varies within `eth_violations' rows"
    local ++test_fail
}

* =========================================================================
* TEST 5: Time-varying variables still vary within IDs
* =========================================================================
local ++test_total
di _n "TEST 5: lab_value varies within IDs (not incorrectly constrained)"

* Count IDs with >1 row that have varying lab_value
tempvar n_rows
bysort patient_id: gen long `n_rows' = _N
tempvar lab_sd
bysort patient_id: egen double `lab_sd' = sd(lab_value)
qui count if `n_rows' > 1 & `lab_sd' > 0
local varying_ids = r(N)
qui count if `n_rows' > 1
local multi_row_obs = r(N)

* At least some multi-row IDs should have varying lab values
if `varying_ids' > 0 {
    di as result "  PASS: lab_value varies within IDs (" `varying_ids' " obs with variation)"
    local ++test_pass
}
else {
    di as error "  FAIL: lab_value appears constant within all multi-row IDs"
    local ++test_fail
}

* =========================================================================
* TEST 6: drug_name (time-varying string) varies within IDs
* =========================================================================
local ++test_total
di _n "TEST 6: drug_name (time-varying string) varies within IDs"

* Count IDs where drug_name is not all the same
tempvar drug_varies
bysort patient_id: gen byte `drug_varies' = (drug_name != drug_name[1])
qui count if `drug_varies' == 1
local drug_varying = r(N)

if `drug_varying' > 0 {
    di as result "  PASS: drug_name varies within IDs (" `drug_varying' " differing rows)"
    local ++test_pass
}
else {
    di as error "  FAIL: drug_name appears constant within all IDs"
    local ++test_fail
}

* =========================================================================
* TEST 7: String distribution is preserved for ethnicity
* =========================================================================
local ++test_total
di _n "TEST 7: ethnicity distribution roughly preserved"

* Get synthetic distribution
preserve
contract ethnicity, freq(synth_freq)
sort ethnicity
qui merge 1:1 ethnicity using `orig_eth_dist', keep(master match using)

* Compare proportions
qui su synth_freq, meanonly
local synth_total = r(sum)
qui su orig_freq, meanonly
local orig_total = r(sum)

gen double synth_pct = synth_freq / `synth_total' * 100
gen double orig_pct = orig_freq / `orig_total' * 100
gen double pct_diff = abs(synth_pct - orig_pct)

qui su pct_diff, meanonly
local max_diff = r(max)
local mean_diff = r(mean)
restore

di "  Max percentage point difference: " %4.1f `max_diff'
di "  Mean percentage point difference: " %4.1f `mean_diff'

* Allow up to 15 percentage points difference (stochastic process)
if `max_diff' < 15 {
    di as result "  PASS: ethnicity distribution preserved (max diff " %4.1f `max_diff' " pp)"
    local ++test_pass
}
else {
    di as error "  FAIL: ethnicity distribution distorted (max diff " %4.1f `max_diff' " pp)"
    local ++test_fail
}

* =========================================================================
* TEST 8: String distribution preserved for drug_name (time-varying)
* =========================================================================
local ++test_total
di _n "TEST 8: drug_name distribution roughly preserved"

preserve
contract drug_name, freq(synth_freq)
sort drug_name
qui merge 1:1 drug_name using `orig_drug_dist', keep(master match using)

qui su synth_freq, meanonly
local synth_total = r(sum)
qui su orig_freq, meanonly
local orig_total = r(sum)

gen double synth_pct = synth_freq / `synth_total' * 100
gen double orig_pct = orig_freq / `orig_total' * 100
gen double pct_diff = abs(synth_pct - orig_pct)

qui su pct_diff, meanonly
local max_diff = r(max)
restore

di "  Max percentage point difference: " %4.1f `max_diff'

if `max_diff' < 15 {
    di as result "  PASS: drug_name distribution preserved (max diff " %4.1f `max_diff' " pp)"
    local ++test_pass
}
else {
    di as error "  FAIL: drug_name distribution distorted (max diff " %4.1f `max_diff' " pp)"
    local ++test_fail
}

* =========================================================================
* TEST 9: Works with n() option (different target size)
* =========================================================================
local ++test_total
di _n "TEST 9: Row count correct with n() option"

use `orig_data', clear
synthdata lab_value bp_systolic sex birth_year, ///
    id(patient_id) smart n(500) replace seed(99)

qui count
local synth_n = r(N)
local target = 500
local row_diff = abs(`synth_n' - `target')
local row_pct = (`row_diff' / `target') * 100

di "  Target rows: `target'"
di "  Synthetic rows: `synth_n'"
di "  Difference: `row_diff' (" %4.1f `row_pct' "%)"

if `row_pct' < 10 {
    di as result "  PASS: Row count within 10% of target"
    local ++test_pass
}
else {
    di as error "  FAIL: Row count drifted " %4.1f `row_pct' "% from target"
    local ++test_fail
}

* =========================================================================
* TEST 10: Constant-within-ID still works with n() option
* =========================================================================
local ++test_total
di _n "TEST 10: Constant-within-ID with n() option"

tempvar sex_const2
bysort patient_id: gen byte `sex_const2' = (sex != sex[1])
qui count if `sex_const2' == 1

if r(N) == 0 {
    di as result "  PASS: sex constant within IDs even with n(500)"
    local ++test_pass
}
else {
    di as error "  FAIL: sex varies within " r(N) " rows"
    local ++test_fail
}

* =========================================================================
* SUMMARY
* =========================================================================
di _n _dup(60) "="
di "TEST SUMMARY: `test_pass'/`test_total' passed, `test_fail'/`test_total' failed"
di _dup(60) "="

if `test_fail' > 0 {
    exit 1
}

clear
