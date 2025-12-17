/*******************************************************************************
* validation_setools.do
* Validation tests for setools package: migrations.ado and sustainedss.ado
*
* Tests:
* - migrations: Basic execution, exclusion logic, censoring dates, return values
* - sustainedss: EDSS progression detection, confirmation window logic
* - Known-answer tests with hand-crafted scenarios
* - Edge cases and error conditions
*******************************************************************************/

version 16.0
set more off
set varabbrev off

/*******************************************************************************
* Configuration
*******************************************************************************/
local test_name "validation_setools"
local stata_path "/usr/local/stata17/stata-mp"

* Path configuration - detect environment
local pwd "`c(pwd)'"
if regexm("`pwd'", "_validation$") {
    local base_path ".."
    local validation_path "."
}
else {
    local base_path "."
    local validation_path "_validation"
}

* Ensure setools is on adopath
adopath ++ "`base_path'/setools"

* Create test data directory
capture mkdir "`validation_path'/data"

local pass_count = 0
local fail_count = 0
local test_num = 0

/*******************************************************************************
* Create Test Datasets for migrations
*******************************************************************************/
di as text _n "=== Creating Test Datasets for migrations ===" _n

* Master cohort data
clear
input long id double study_start
1 21185   // 01jan2018 - stays in Sweden
2 21185   // 01jan2018 - emigrates before, never returns (exclude)
3 21185   // 01jan2018 - immigrates after start (exclude)
4 21185   // 01jan2018 - emigrates during study (censor)
5 21185   // 01jan2018 - complex: multiple migrations
end
format study_start %td
label data "Master cohort for migration testing"
save "`validation_path'/data/val_mig_master.dta", replace

* Migration data (wide format with in_/out_)
* Person 1: No migration (not in file - stays in Sweden)
* Person 2: Left 01jul2017, never returned
* Person 3: First entry 01mar2018 (after study start)
* Person 4: Left 01jul2018 (censor date)
* Person 5: Left 01mar2018, returned 01jun2018, left again 01sep2018
clear
input long id double(in_1 out_1 in_2 out_2)
2 .     20999 .     .       // out_1=01jul2017
3 21244 .     .     .       // in_1=01mar2018
4 .     21366 .     .       // out_1=01jul2018
5 .     21244 21336 21427   // out_1=01mar2018, in_2=01jun2018, out_2=01sep2018
end
format in_1 out_1 in_2 out_2 %td
label data "Migration data for testing"
save "`validation_path'/data/val_mig_migrations.dta", replace

di as text "Migration test datasets created successfully."

/*******************************************************************************
* Create Test Datasets for sustainedss
*******************************************************************************/
di as text _n "=== Creating Test Datasets for sustainedss ===" _n

* Dataset with known-answer sustained progression scenarios
* Using EDSS scale (0-10, steps of 0.5)
* threshold=6.0, confirmwindow=182 (default), baselinethreshold=4.0 (default)

clear
input long id double edss double edss_dt
// Person 1: Clear sustained progression
// Reaches 6.0 on day 100, confirmed at 6.5 on day 200 -> sustained_dt = day 100
1 3.5 21285   // 01apr2018: baseline
1 5.0 21350   // 05jun2018: intermediate
1 6.0 21385   // 10jul2018: threshold reached (day ~200 from start)
1 6.5 21450   // 13sep2018: confirmed

// Person 2: NOT sustained (drops below 4.0 in window)
// Reaches 6.0 but drops to 3.5 and ends at 5.0 in window -> not sustained
2 4.0 21285   // 01apr2018: baseline
2 6.0 21350   // 05jun2018: threshold reached
2 3.5 21400   // 25jul2018: dropped below baselinethreshold
2 5.0 21500   // 02nov2018: still below threshold at window end

// Person 3: Sustained despite fluctuation (stays >= baselinethreshold)
// Reaches 6.0, drops to 4.5 (>=4) but ends at 6.0 -> sustained
3 4.0 21285   // 01apr2018: baseline
3 6.0 21350   // 05jun2018: threshold reached
3 4.5 21400   // 25jul2018: dropped but still >= baselinethreshold
3 6.0 21500   // 02nov2018: back at threshold

// Person 4: Never reaches threshold
4 3.0 21285   // 01apr2018: baseline
4 4.5 21350   // 05jun2018: below threshold
4 5.5 21450   // 13sep2018: still below threshold

// Person 5: Reaches threshold at first observation
5 6.5 21285   // 01apr2018: above threshold immediately
5 7.0 21450   // 13sep2018: confirmed
end
format edss_dt %td
label data "EDSS data for sustainedss testing"
save "`validation_path'/data/val_edss.dta", replace

di as text "EDSS test dataset created successfully."

/*******************************************************************************
* Section 1: migrations - Basic Execution
*******************************************************************************/
di as text _n "=== Section 1: migrations Basic Execution ===" _n

* Test 1.1: Basic execution
local ++test_num
di as text "Test `test_num': migrations basic execution"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
if _rc == 0 {
    di as result "  PASS: migrations executed without error"
    local ++pass_count
}
else {
    di as error "  FAIL: migrations failed with rc = `=_rc'"
    local ++fail_count
}

* Test 1.2: Return value r(N_final)
local ++test_num
di as text "Test `test_num': Return value r(N_final)"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
if r(N_final) >= 0 {
    di as result "  PASS: r(N_final) = `r(N_final)'"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_final) not returned correctly"
    local ++fail_count
}

/*******************************************************************************
* Section 2: migrations - Known-Answer Tests (Exclusion Logic)
*******************************************************************************/
di as text _n "=== Section 2: migrations Known-Answer Tests ===" _n

* Test 2.1: Correct exclusion count for emigrated-never-returned
local ++test_num
di as text "Test `test_num': Exclusion - emigrated before start, never returned"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
* Person 2 should be excluded (emigrated before, never returned)
if r(N_excluded_emigrated) == 1 {
    di as result "  PASS: r(N_excluded_emigrated) = 1 as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_excluded_emigrated) = `r(N_excluded_emigrated)', expected 1"
    local ++fail_count
}

* Test 2.2: Correct exclusion count for immigration after start
local ++test_num
di as text "Test `test_num': Exclusion - immigration after study start"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
* Person 3 should be excluded (immigrated after start)
if r(N_excluded_inmigration) == 1 {
    di as result "  PASS: r(N_excluded_inmigration) = 1 as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_excluded_inmigration) = `r(N_excluded_inmigration)', expected 1"
    local ++fail_count
}

* Test 2.3: Total exclusions
local ++test_num
di as text "Test `test_num': Total exclusions count"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
if r(N_excluded_total) == 2 {
    di as result "  PASS: r(N_excluded_total) = 2 as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_excluded_total) = `r(N_excluded_total)', expected 2"
    local ++fail_count
}

* Test 2.4: Censoring count
local ++test_num
di as text "Test `test_num': Censoring count"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
* Person 4 and possibly 5 should have censoring dates
if r(N_censored) >= 1 {
    di as result "  PASS: r(N_censored) = `r(N_censored)' >= 1"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_censored) = `r(N_censored)', expected >= 1"
    local ++fail_count
}

* Test 2.5: Final sample size (5 - 2 excluded = 3)
local ++test_num
di as text "Test `test_num': Final sample size"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
}
if r(N_final) == 3 {
    di as result "  PASS: r(N_final) = 3 as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_final) = `r(N_final)', expected 3"
    local ++fail_count
}

/*******************************************************************************
* Section 3: migrations - Censoring Date Variable
*******************************************************************************/
di as text _n "=== Section 3: migrations Censoring Date Variable ===" _n

* Test 3.1: migration_out_dt variable created
local ++test_num
di as text "Test `test_num': migration_out_dt variable created"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
    confirm variable migration_out_dt
}
if _rc == 0 {
    di as result "  PASS: migration_out_dt variable exists"
    local ++pass_count
}
else {
    di as error "  FAIL: migration_out_dt variable not created"
    local ++fail_count
}

* Test 3.2: Person 4's censoring date is correct
local ++test_num
di as text "Test `test_num': Person 4 censoring date (01jul2018)"
local censor_dt = .
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta")
    sum migration_out_dt if id == 4
    if r(N) > 0 {
        local censor_dt = r(mean)
    }
}
* 01jul2018 = 21366
if `censor_dt' != . & `censor_dt' == 21366 {
    di as result "  PASS: Person 4 censoring date = 01jul2018"
    local ++pass_count
}
else {
    di as error "  FAIL: Person 4 censoring date missing or incorrect"
    local ++fail_count
}

/*******************************************************************************
* Section 4: migrations - Options
*******************************************************************************/
di as text _n "=== Section 4: migrations Options ===" _n

* Test 4.1: verbose option
local ++test_num
di as text "Test `test_num': verbose option"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta") verbose
}
if _rc == 0 {
    di as result "  PASS: verbose option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: verbose option failed"
    local ++fail_count
}

* Test 4.2: savecensor option
local ++test_num
di as text "Test `test_num': savecensor option"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta") ///
        savecensor("`validation_path'/data/test_censor.dta") replace
    confirm file "`validation_path'/data/test_censor.dta"
}
if _rc == 0 {
    di as result "  PASS: savecensor creates file"
    local ++pass_count
}
else {
    di as error "  FAIL: savecensor failed"
    local ++fail_count
}

* Test 4.3: saveexclude option
local ++test_num
di as text "Test `test_num': saveexclude option"
capture {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta") ///
        saveexclude("`validation_path'/data/test_exclude.dta") replace
    confirm file "`validation_path'/data/test_exclude.dta"
}
if _rc == 0 {
    di as result "  PASS: saveexclude creates file"
    local ++pass_count
}
else {
    di as error "  FAIL: saveexclude failed"
    local ++fail_count
}

/*******************************************************************************
* Section 5: migrations - Error Conditions
*******************************************************************************/
di as text _n "=== Section 5: migrations Error Conditions ===" _n

* Test 5.1: Error when migfile not found
local ++test_num
di as text "Test `test_num': Error when migfile not found"
capture noisily {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("nonexistent.dta")
}
if _rc == 601 {
    di as result "  PASS: Correctly errored with rc 601"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 601, got `=_rc'"
    local ++fail_count
}

* Test 5.2: Error when idvar not in master
local ++test_num
di as text "Test `test_num': Error when idvar not in master"
capture noisily {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta") idvar(nonexistent)
}
if _rc == 111 {
    di as result "  PASS: Correctly errored with rc 111"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 111, got `=_rc'"
    local ++fail_count
}

* Test 5.3: Error when startvar not in master
local ++test_num
di as text "Test `test_num': Error when startvar not in master"
capture noisily {
    use "`validation_path'/data/val_mig_master.dta", clear
    migrations, migfile("`validation_path'/data/val_mig_migrations.dta") startvar(nonexistent)
}
if _rc == 111 {
    di as result "  PASS: Correctly errored with rc 111"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 111, got `=_rc'"
    local ++fail_count
}

/*******************************************************************************
* Section 6: sustainedss - Basic Execution
*******************************************************************************/
di as text _n "=== Section 6: sustainedss Basic Execution ===" _n

* Test 6.1: Basic execution
local ++test_num
di as text "Test `test_num': sustainedss basic execution"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0)
}
if _rc == 0 {
    di as result "  PASS: sustainedss executed without error"
    local ++pass_count
}
else {
    di as error "  FAIL: sustainedss failed with rc = `=_rc'"
    local ++fail_count
}

* Test 6.2: Return value r(threshold)
local ++test_num
di as text "Test `test_num': Return value r(threshold)"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0)
}
if r(threshold) == 6.0 {
    di as result "  PASS: r(threshold) = `r(threshold)' as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(threshold) = `r(threshold)', expected 6.0"
    local ++fail_count
}

* Test 6.3: Return value r(confirmwindow)
local ++test_num
di as text "Test `test_num': Return value r(confirmwindow)"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0)
}
if r(confirmwindow) == 182 {
    di as result "  PASS: r(confirmwindow) = `r(confirmwindow)' (default)"
    local ++pass_count
}
else {
    di as error "  FAIL: r(confirmwindow) = `r(confirmwindow)', expected 182"
    local ++fail_count
}

* Test 6.4: Generated variable created
local ++test_num
di as text "Test `test_num': Generated variable created"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) keepall
    confirm variable sustained6_0_dt
}
if _rc == 0 {
    di as result "  PASS: sustained6_0_dt variable exists"
    local ++pass_count
}
else {
    di as error "  FAIL: sustained6_0_dt variable not created"
    local ++fail_count
}

/*******************************************************************************
* Section 7: sustainedss - Known-Answer Tests
*******************************************************************************/
di as text _n "=== Section 7: sustainedss Known-Answer Tests ===" _n

* Test 7.1: Person 1 has sustained progression
local ++test_num
di as text "Test `test_num': Person 1 has sustained progression"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall
    sum sust_dt if id == 1
    local has_event = (r(N) > 0 & !missing(r(mean)))
}
if `has_event' {
    di as result "  PASS: Person 1 has sustained event"
    local ++pass_count
}
else {
    di as error "  FAIL: Person 1 should have sustained event"
    local ++fail_count
}

* Test 7.2: Person 2 does NOT have sustained progression (dropped below baseline)
local ++test_num
di as text "Test `test_num': Person 2 NOT sustained (drops < baselinethreshold)"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall
    sum sust_dt if id == 2
    local no_event = (missing(r(mean)) | r(N) == 0)
}
if `no_event' {
    di as result "  PASS: Person 2 correctly has no sustained event"
    local ++pass_count
}
else {
    di as error "  FAIL: Person 2 should NOT have sustained event"
    local ++fail_count
}

* Test 7.3: Person 3 has sustained progression (stays >= baselinethreshold)
local ++test_num
di as text "Test `test_num': Person 3 sustained (stays >= baselinethreshold)"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall
    sum sust_dt if id == 3
    local has_event = (r(N) > 0 & !missing(r(mean)))
}
if `has_event' {
    di as result "  PASS: Person 3 has sustained event"
    local ++pass_count
}
else {
    di as error "  FAIL: Person 3 should have sustained event"
    local ++fail_count
}

* Test 7.4: Person 4 never reaches threshold
local ++test_num
di as text "Test `test_num': Person 4 never reaches threshold"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall
    sum sust_dt if id == 4
    local no_event = (missing(r(mean)) | r(N) == 0)
}
if `no_event' {
    di as result "  PASS: Person 4 correctly has no sustained event"
    local ++pass_count
}
else {
    di as error "  FAIL: Person 4 should NOT have sustained event"
    local ++fail_count
}

* Test 7.5: Person 5 has sustained progression (immediate threshold)
local ++test_num
di as text "Test `test_num': Person 5 sustained (immediate threshold)"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall
    sum sust_dt if id == 5
    local has_event = (r(N) > 0 & !missing(r(mean)))
}
if `has_event' {
    di as result "  PASS: Person 5 has sustained event"
    local ++pass_count
}
else {
    di as error "  FAIL: Person 5 should have sustained event"
    local ++fail_count
}

* Test 7.6: Total event count
local ++test_num
di as text "Test `test_num': Total events = 3 (persons 1, 3, 5)"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall
}
* Expect 3 events: persons 1, 3, 5
if r(N_events) == 3 {
    di as result "  PASS: r(N_events) = 3 as expected"
    local ++pass_count
}
else {
    di as error "  FAIL: r(N_events) = `r(N_events)', expected 3"
    local ++fail_count
}

/*******************************************************************************
* Section 8: sustainedss - Options
*******************************************************************************/
di as text _n "=== Section 8: sustainedss Options ===" _n

* Test 8.1: Custom generate name
local ++test_num
di as text "Test `test_num': Custom generate(mydate) option"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(mydate) keepall
    confirm variable mydate
}
if _rc == 0 {
    di as result "  PASS: Custom variable name accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: Custom variable name failed"
    local ++fail_count
}

* Test 8.2: Custom confirmwindow
local ++test_num
di as text "Test `test_num': confirmwindow(365) option"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) confirmwindow(365) keepall
}
if r(confirmwindow) == 365 {
    di as result "  PASS: confirmwindow = 365 accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: confirmwindow not set correctly"
    local ++fail_count
}

* Test 8.3: Custom baselinethreshold
local ++test_num
di as text "Test `test_num': baselinethreshold(5.0) option"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) baselinethreshold(5.0) keepall generate(test_bt)
}
if _rc == 0 {
    di as result "  PASS: baselinethreshold(5.0) accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: baselinethreshold option failed"
    local ++fail_count
}

* Test 8.4: keepall option preserves all observations
local ++test_num
di as text "Test `test_num': keepall preserves original data"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    local orig_n = _N
    sustainedss id edss edss_dt, threshold(6.0) keepall generate(test_keep)
    local new_n = _N
}
if `orig_n' == `new_n' {
    di as result "  PASS: keepall preserves all `new_n' observations"
    local ++pass_count
}
else {
    di as error "  FAIL: Original N=`orig_n', after keepall N=`new_n'"
    local ++fail_count
}

* Test 8.5: quietly option
local ++test_num
di as text "Test `test_num': quietly option"
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) keepall generate(test_quiet) quietly
}
if _rc == 0 {
    di as result "  PASS: quietly option accepted"
    local ++pass_count
}
else {
    di as error "  FAIL: quietly option failed"
    local ++fail_count
}

/*******************************************************************************
* Section 9: sustainedss - Error Conditions
*******************************************************************************/
di as text _n "=== Section 9: sustainedss Error Conditions ===" _n

* Test 9.1: Error when threshold <= 0
local ++test_num
di as text "Test `test_num': Error when threshold <= 0"
capture noisily {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(0)
}
if _rc == 198 {
    di as result "  PASS: Correctly errored with rc 198"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 198, got `=_rc'"
    local ++fail_count
}

* Test 9.2: Error when generate variable already exists
local ++test_num
di as text "Test `test_num': Error when variable already exists"
capture noisily {
    use "`validation_path'/data/val_edss.dta", clear
    gen myexistingvar = .
    sustainedss id edss edss_dt, threshold(6.0) generate(myexistingvar)
}
if _rc == 110 {
    di as result "  PASS: Correctly errored with rc 110"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 110, got `=_rc'"
    local ++fail_count
}

* Test 9.3: Error when no valid observations
local ++test_num
di as text "Test `test_num': Error when no valid observations"
capture noisily {
    clear
    set obs 5
    gen id = _n
    gen edss = .
    gen edss_dt = .
    sustainedss id edss edss_dt, threshold(6.0)
}
if _rc == 2000 {
    di as result "  PASS: Correctly errored with rc 2000"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 2000, got `=_rc'"
    local ++fail_count
}

* Test 9.4: Error when edss not numeric
local ++test_num
di as text "Test `test_num': Error when edss not numeric"
capture noisily {
    clear
    set obs 5
    gen id = _n
    gen str10 edss = "6.0"
    gen edss_dt = td(01jan2020)
    sustainedss id edss edss_dt, threshold(6.0)
}
if _rc == 109 {
    di as result "  PASS: Correctly errored with rc 109"
    local ++pass_count
}
else {
    di as error "  FAIL: Expected rc 109, got `=_rc'"
    local ++fail_count
}

/*******************************************************************************
* Section 10: sustainedss - Invariants
*******************************************************************************/
di as text _n "=== Section 10: sustainedss Invariants ===" _n

* Test 10.1: Sustained date is always >= first threshold crossing
local ++test_num
di as text "Test `test_num': Sustained date >= first threshold crossing"
local all_valid = 0
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt) keepall

    * Check for each person with event
    gen first_cross = edss_dt if edss >= 6.0
    bysort id: egen min_first_cross = min(first_cross)

    * Verify sustained date >= first crossing
    gen valid = (sust_dt >= min_first_cross) if !missing(sust_dt) & !missing(min_first_cross)
    sum valid
    if r(N) > 0 {
        local all_valid = (r(min) == 1)
    }
    else {
        local all_valid = 1
    }
}
if `all_valid' == 1 {
    di as result "  PASS: All sustained dates >= first threshold crossing"
    local ++pass_count
}
else {
    di as error "  FAIL: Some sustained dates before first crossing"
    local ++fail_count
}

* Test 10.2: Deterministic results (same input -> same output)
local ++test_num
di as text "Test `test_num': Deterministic results"
local same = 0
capture {
    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt1) keepall

    use "`validation_path'/data/val_edss.dta", clear
    sustainedss id edss edss_dt, threshold(6.0) generate(sust_dt2) keepall

    * Compare
    gen diff = sust_dt1 != sust_dt2 if !missing(sust_dt1) | !missing(sust_dt2)
    sum diff
    local same = (r(sum) == 0 | r(N) == 0)
}
if `same' == 1 {
    di as result "  PASS: Results are deterministic"
    local ++pass_count
}
else {
    di as error "  FAIL: Results differ between runs"
    local ++fail_count
}

/*******************************************************************************
* Cleanup and Summary
*******************************************************************************/
di as text _n "=== Cleaning up test files ===" _n

* Remove test datasets
capture erase "`validation_path'/data/val_mig_master.dta"
capture erase "`validation_path'/data/val_mig_migrations.dta"
capture erase "`validation_path'/data/val_edss.dta"
capture erase "`validation_path'/data/test_censor.dta"
capture erase "`validation_path'/data/test_exclude.dta"

/*******************************************************************************
* Final Summary
*******************************************************************************/
di as text _n "=========================================="
di as text "VALIDATION SUMMARY: `test_name'"
di as text "=========================================="
di as text "Total tests: `test_num'"
di as result "Passed: `pass_count'"
if `fail_count' > 0 {
    di as error "Failed: `fail_count'"
}
else {
    di as text "Failed: `fail_count'"
}
di as text "==========================================" _n

if `fail_count' > 0 {
    exit 1
}
