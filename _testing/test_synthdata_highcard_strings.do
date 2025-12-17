// test_synthdata_highcard_strings.do
// Test synthdata with high-cardinality string variables (like ATC codes, substance names)
// This tests the new Mata-based approach that avoids local macro limits

version 16.0
clear all
set more off

// Create test data with high-cardinality string variables
// Simulating prescription data patterns

local n_obs = 5000
local n_atc = 2000      // Number of unique ATC codes
local n_substance = 1500 // Number of unique substances
local n_packsize = 500   // Number of unique pack sizes

di as txt _n "Creating test dataset with high-cardinality strings..."
di as txt "  Observations: `n_obs'"
di as txt "  Unique ATC codes: `n_atc'"
di as txt "  Unique substances: `n_substance'"
di as txt "  Unique pack sizes: `n_packsize'"

set obs `n_obs'
set seed 12345

// Generate patient IDs
gen long patid = _n

// Generate high-cardinality string variables
// Uses vectorized operations for speed

// Random index for code generation
gen int code_idx = ceil(runiform() * `n_atc')

// ATC codes - build from components using string functions
gen str1 l1 = char(65 + mod(code_idx-1, 26))
gen int d1 = mod(code_idx-1, 10)
gen int d2 = mod(floor((code_idx-1)/10), 10)
gen str1 l2 = char(65 + mod(floor((code_idx-1)/100), 26))
gen str1 l3 = char(65 + mod(floor((code_idx-1)/260), 26))
gen int d3 = mod(floor((code_idx-1)/26), 10)
gen int d4 = mod(floor((code_idx-1)/2600), 10)
gen str7 atc_code = l1 + string(d1) + string(d2) + l2 + l3 + string(d3) + string(d4)
drop code_idx l1 d1 d2 l2 l3 d3 d4

// Substance names
gen str30 substance = "Substance_" + string(ceil(runiform() * `n_substance'), "%04.0f")

// Pack sizes
gen str20 pack_size = string(ceil(runiform() * 100)) + "x" + string(ceil(runiform() * 500)) + "mg"

// Add some numeric variables too
gen double price = runiform() * 500 + 10
gen int quantity = ceil(runiform() * 10)
gen dispdate = date("2020-01-01", "YMD") + floor(runiform() * 1000)
format dispdate %td

// Report unique values
qui levelsof atc_code, local(atc_levels) clean
di as txt _n "Actual unique ATC codes: " as res `: word count `atc_levels''

qui levelsof substance, local(sub_levels) clean
di as txt "Actual unique substances: " as res `: word count `sub_levels''

qui levelsof pack_size, local(pack_levels) clean
di as txt "Actual unique pack sizes: " as res `: word count `pack_levels''

// Store original data
tempfile origdata
save `origdata'

// ============================================================================
// TEST 1: Parametric synthesis with high-cardinality strings
// ============================================================================
di as txt _n "=" _dup(70) "="
di as txt "TEST 1: Parametric synthesis with high-cardinality strings"
di as txt "=" _dup(70) "="

use `origdata', clear

cap noisily synthdata atc_code substance pack_size price quantity dispdate, ///
    id(patid) dates(dispdate) n(1000) seed(54321)

if _rc == 0 {
    di as txt _n "SUCCESS: Synthesis completed without error"

    // Check output
    di as txt _n "Synthetic data summary:"
    describe

    // Check that string variables were created
    cap confirm string variable atc_code
    if _rc == 0 {
        qui levelsof atc_code, local(synth_atc) clean
        di as txt "Synthetic unique ATC codes: " as res `: word count `synth_atc''
    }
    else {
        di as error "ERROR: atc_code not found or not string"
    }

    cap confirm string variable substance
    if _rc == 0 {
        qui levelsof substance, local(synth_sub) clean
        di as txt "Synthetic unique substances: " as res `: word count `synth_sub''
    }
    else {
        di as error "ERROR: substance not found or not string"
    }
}
else {
    di as error "TEST 1 FAILED with error code: " _rc
}

// ============================================================================
// TEST 2: Sequential synthesis with high-cardinality strings
// ============================================================================
di as txt _n "=" _dup(70) "="
di as txt "TEST 2: Sequential synthesis with high-cardinality strings"
di as txt "=" _dup(70) "="

use `origdata', clear

cap noisily synthdata atc_code substance price, ///
    id(patid) n(500) seed(11111) sequential

if _rc == 0 {
    di as txt _n "SUCCESS: Sequential synthesis completed"
    describe
}
else {
    di as error "TEST 2 FAILED with error code: " _rc
}

// ============================================================================
// TEST 3: Bootstrap synthesis (should just resample, no string issues)
// ============================================================================
di as txt _n "=" _dup(70) "="
di as txt "TEST 3: Bootstrap synthesis with high-cardinality strings"
di as txt "=" _dup(70) "="

use `origdata', clear

cap noisily synthdata atc_code substance price, ///
    id(patid) n(500) seed(22222) bootstrap

if _rc == 0 {
    di as txt _n "SUCCESS: Bootstrap synthesis completed"
    describe
}
else {
    di as error "TEST 3 FAILED with error code: " _rc
}

// ============================================================================
// TEST 4: Empty/missing string variable handling
// ============================================================================
di as txt _n "=" _dup(70) "="
di as txt "TEST 4: Empty string variable handling"
di as txt "=" _dup(70) "="

clear
set obs 100
gen str10 empty_var = ""
gen double x = rnormal()

cap noisily synthdata empty_var x, n(50) seed(33333)

if _rc == 0 {
    di as txt _n "SUCCESS: Empty string handling completed"
    describe
}
else {
    di as error "TEST 4 FAILED with error code: " _rc
}

// ============================================================================
// Summary
// ============================================================================
di as txt _n "=" _dup(70) "="
di as txt "ALL TESTS COMPLETED"
di as txt "=" _dup(70) "="

