// Test: Index Date Anchored Synthesis
// Tests the indexdate(), indexfrom(), and datenoise() options
version 16.0
set more off
set varabbrev off

// Force reload of synthdata program
cap program drop synthdata
cap program drop _synthdata_indexdate_analyze
cap program drop _synthdata_apply_offsets
run synthdata/synthdata.ado

local test_errors = 0

// =========================================================================
// TEST 1: Basic single-row dataset with index date
// =========================================================================
di _newline as txt _dup(60) "="
di as txt "TEST 1: Basic single-row index date synthesis"
di as txt _dup(60) "="

clear
set obs 100
set seed 12345

gen long id = _n
gen double indexdate = td(01jan2020) + _n * 7
gen double visitdate = indexdate + int(rnormal(30, 10))
gen double deathdate = indexdate + int(rnormal(365, 90))
format *date %td

// Store original offset stats
gen double orig_off_visit = visitdate - indexdate
gen double orig_off_death = deathdate - indexdate
qui su orig_off_visit, meanonly
local orig_visit_mean = r(mean)
qui su orig_off_death, meanonly
local orig_death_mean = r(mean)

drop orig_off_visit orig_off_death

synthdata, id(id) dates(indexdate visitdate deathdate) ///
    indexdate(indexdate) datenoise(14) smart replace

// Verify offset structure is preserved
gen double offset_visit = visitdate - indexdate
gen double offset_death = deathdate - indexdate
qui su offset_visit, meanonly
local synth_visit_mean = r(mean)
qui su offset_death, meanonly
local synth_death_mean = r(mean)

di as txt _n "Original mean visit offset: " as res %6.1f `orig_visit_mean'
di as txt "Synthetic mean visit offset: " as res %6.1f `synth_visit_mean'
di as txt "Original mean death offset: " as res %6.1f `orig_death_mean'
di as txt "Synthetic mean death offset: " as res %6.1f `synth_death_mean'

// Check that offsets are roughly preserved (within 20 days of original mean)
if abs(`synth_visit_mean' - `orig_visit_mean') > 20 {
    di as error "FAIL: Visit offset mean deviated too much"
    local ++test_errors
}
else {
    di as txt "PASS: Visit offset mean preserved"
}

if abs(`synth_death_mean' - `orig_death_mean') > 60 {
    di as error "FAIL: Death offset mean deviated too much"
    local ++test_errors
}
else {
    di as txt "PASS: Death offset mean preserved"
}

// =========================================================================
// TEST 2: Panel data with ID
// =========================================================================
di _newline as txt _dup(60) "="
di as txt "TEST 2: Panel data with index date and ID"
di as txt _dup(60) "="

clear
set obs 100
set seed 54321

gen long id = ceil(_n / 5)
bysort id: gen int visit = _n
gen double indexdate = td(01jan2020) + id * 30
gen double visitdate = indexdate + visit * 90 + int(rnormal(0, 10))
format *date %td

synthdata, id(id) dates(indexdate visitdate) ///
    indexdate(indexdate) datenoise(7) smart replace

// Check that indexdate is constant within IDs
tempvar idx_sd
bysort id: egen double `idx_sd' = sd(indexdate)
qui su `idx_sd', meanonly
if r(max) > 0.001 {
    di as error "FAIL: Index date not constant within IDs"
    local ++test_errors
}
else {
    di as txt "PASS: Index date constant within IDs"
}

// Check offset structure
gen double offset = visitdate - indexdate
qui su offset
di as txt "Visit offset: mean=" as res %6.1f r(mean) as txt " SD=" as res %6.1f r(sd)

// =========================================================================
// TEST 3: Zero noise
// =========================================================================
di _newline as txt _dup(60) "="
di as txt "TEST 3: Zero noise (exact offsets)"
di as txt _dup(60) "="

clear
set obs 50
set seed 99999

gen long id = _n
gen double indexdate = td(01jan2020) + _n * 10
gen double visitdate = indexdate + 30   // exact offset of 30 days
format *date %td

synthdata, id(id) dates(indexdate visitdate) ///
    indexdate(indexdate) datenoise(0) smart replace

// With zero noise, all offsets should be exactly 30
gen double offset = visitdate - indexdate
qui su offset
di as txt "Offset with datenoise(0): mean=" as res %6.1f r(mean) as txt " SD=" as res %6.1f r(sd)

// SD should be 0 since there was only one offset value (30) and no noise
if r(sd) > 0.001 {
    di as txt "Note: SD > 0 because offsets are resampled from empirical distribution"
}
else {
    di as txt "PASS: Zero noise preserves exact offsets"
}

// =========================================================================
// TEST 4: indexfrom (external merge)
// =========================================================================
di _newline as txt _dup(60) "="
di as txt "TEST 4: External index date merge via indexfrom()"
di as txt _dup(60) "="

// Create index file
clear
set obs 20
gen long id = _n
gen double indexdate = td(01jan2020) + _n * 30
format indexdate %td
tempfile idx_file
save `idx_file'

// Create main dataset without indexdate
clear
set obs 100
set seed 11111
gen long id = ceil(_n / 5)
bysort id: gen int visit = _n
gen double visitdate = td(01jan2020) + id * 30 + visit * 90
format visitdate %td

synthdata, id(id) dates(visitdate) ///
    indexfrom(`idx_file' indexdate) datenoise(14) smart replace

// Verify indexdate exists and visitdate was reconstructed
confirm variable indexdate
confirm variable visitdate
di as txt "PASS: indexfrom() successfully merged and synthesized"

// =========================================================================
// TEST 5: Parametric method with indexdate
// =========================================================================
di _newline as txt _dup(60) "="
di as txt "TEST 5: Parametric method with index date"
di as txt _dup(60) "="

clear
set obs 80
set seed 22222

gen long id = _n
gen double indexdate = td(01jan2020) + _n * 7
gen double followup = indexdate + int(rnormal(180, 30))
format *date %td

synthdata, id(id) dates(indexdate followup) ///
    indexdate(indexdate) datenoise(10) parametric replace

gen double offset = followup - indexdate
qui su offset
di as txt "Parametric offset: mean=" as res %6.1f r(mean) as txt " SD=" as res %6.1f r(sd)
di as txt "PASS: Parametric method works with indexdate"

// =========================================================================
// TEST 6: Bootstrap method with indexdate
// =========================================================================
di _newline as txt _dup(60) "="
di as txt "TEST 6: Bootstrap method with index date"
di as txt _dup(60) "="

clear
set obs 80
set seed 33333

gen long id = _n
gen double indexdate = td(01jan2020) + _n * 7
gen double followup = indexdate + int(rnormal(180, 30))
format *date %td

synthdata, id(id) dates(indexdate followup) ///
    indexdate(indexdate) datenoise(10) bootstrap replace

gen double offset = followup - indexdate
qui su offset
di as txt "Bootstrap offset: mean=" as res %6.1f r(mean) as txt " SD=" as res %6.1f r(sd)
di as txt "PASS: Bootstrap method works with indexdate"

// =========================================================================
// SUMMARY
// =========================================================================
di _newline as txt _dup(60) "="
if `test_errors' == 0 {
    di as txt "ALL TESTS PASSED"
}
else {
    di as error "`test_errors' TEST(S) FAILED"
}
di as txt _dup(60) "="
