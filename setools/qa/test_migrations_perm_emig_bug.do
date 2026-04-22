* test_migrations_perm_emig_bug.do
* Known-answer test: permanent emigration detection bug in migrations.ado
*
* Bug: Line 240 uses row-level in_ (same reshape index) instead of
*      person-level _mig_last_in, producing false censoring dates for
*      immigrants who emigrate and later return.
*
* Test persons:
*   1 — Immigrant who emigrates temporarily (BUG CASE)
*   2 — Native who emigrates permanently (control, should censor)
*   3 — Native who emigrates temporarily (control, no censor)
*   4 — No migration record (control, retained, no censor)

clear all
set more off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall setools
net install setools, from("`pkg_dir'")

local passed = 0
local failed = 0

* ============================================================
* Create master cohort dataset
* ============================================================
clear
input long id
1
2
3
4
end
gen long study_start = td(01jan2018)
format study_start %td
tempfile cohort
save `cohort'

* ============================================================
* Create migration wide dataset
* ============================================================
*
* Person 1 (immigrant, temporary emigration):
*   in_1 = 2015-03-01 (initial immigration to Sweden)
*   out_1 = 2020-06-01 (emigrates after study start)
*   in_2 = 2021-01-01  (returns to Sweden)
*   out_2 = .           (stays)
*   Expected: NO censoring date (emigration was temporary)
*
* Person 2 (native, permanent emigration):
*   in_1 = .
*   out_1 = 2020-06-01 (emigrates, never returns)
*   in_2 = .
*   out_2 = .
*   Expected: censoring date = 2020-06-01
*
* Person 3 (native, temporary emigration):
*   in_1 = 2021-01-01  (returns after emigration)
*   out_1 = 2020-06-01 (emigrates)
*   in_2 = .
*   out_2 = .
*   Expected: NO censoring date (returned)

clear
set obs 3
gen long id = _n
gen long in_1 = .
gen long out_1 = td(01jun2020)
gen long in_2 = .
gen long out_2 = .

* Person 1: immigrant who emigrates and returns
replace in_1 = td(01mar2015) if id == 1
replace in_2 = td(01jan2021) if id == 1

* Person 2: permanent emigration (no immigration records)
* Already set: out_1 only

* Person 3: temporary emigration (native born)
replace in_1 = td(01jan2021) if id == 3

format in_* out_* %td

tempfile migwide
save `migwide'

* ============================================================
* Run migrations
* ============================================================
use `cohort', clear
migrations, migfile("`migwide'") verbose

capture assert r(N_excluded_total) == 0 & r(N_censored) == 1 & r(N_final) == 4
if _rc == 0 {
    display as result "[PASS] Wide format returns: excluded=0 censored=1 final=4"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Wide format returns do not match expected counts"
    local failed = `failed' + 1
}

* ============================================================
* Verify results
* ============================================================

* --- Person 1: immigrant with temporary emigration ---
* Should have NO censoring date (returned in 2021)
* BUG: code sets migration_out_dt = 2020-06-01
capture assert migration_out_dt == . if id == 1
if _rc == 0 {
    display as result "[PASS] Person 1: no censoring date (temporary emigration)"
    local passed = `passed' + 1
}
else {
    summarize migration_out_dt if id == 1, format
    display as error "[FAIL] Person 1: has censoring date but emigration was temporary"
    display as error "       Expected: missing  Got: " %td migration_out_dt[1] " (if id==1)"
    local failed = `failed' + 1
}

* --- Person 2: permanent emigration ---
* Should have censoring date = 2020-06-01
capture assert migration_out_dt == td(01jun2020) if id == 2
if _rc == 0 {
    display as result "[PASS] Person 2: correct censoring date for permanent emigration"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Person 2: wrong censoring date for permanent emigration"
    local failed = `failed' + 1
}

* --- Person 3: native with temporary emigration ---
* Should have NO censoring date
capture assert migration_out_dt == . if id == 3
if _rc == 0 {
    display as result "[PASS] Person 3: no censoring date (temporary emigration)"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Person 3: has censoring date but emigration was temporary"
    local failed = `failed' + 1
}

* --- Person 4: no migration record ---
* Should be retained with no censoring date
quietly count if id == 4
capture assert r(N) == 1
if _rc == 0 {
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Person 4: missing from final dataset"
    local failed = `failed' + 1
}

capture assert migration_out_dt == . if id == 4
if _rc == 0 {
    display as result "[PASS] Person 4: retained with no censoring date"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Person 4: has unexpected censoring date"
    local failed = `failed' + 1
}

* ============================================================
* Re-run the same known-answer test with long-format migration data
* ============================================================
clear
set obs 6
gen long id = .
gen double event_date = .
gen str3 event_type = ""
replace id = 1 in 1/3
replace id = 2 in 4
replace id = 3 in 5/6
replace event_date = td(01mar2015) in 1
replace event_date = td(01jun2020) in 2
replace event_date = td(01jan2021) in 3
replace event_date = td(01jun2020) in 4
replace event_date = td(01jun2020) in 5
replace event_date = td(01jan2021) in 6
replace event_type = "Inv" in 1
replace event_type = "Utv" in 2
replace event_type = "Inv" in 3
replace event_type = "Utv" in 4
replace event_type = "Utv" in 5
replace event_type = "Inv" in 6
format event_date %td
tempfile miglong
save `miglong'

use `cohort', clear
migrations, migfile("`miglong'") verbose

capture assert r(N_excluded_total) == 0 & r(N_censored) == 1 & r(N_final) == 4
if _rc == 0 {
    display as result "[PASS] Long format returns: excluded=0 censored=1 final=4"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Long format returns do not match expected counts"
    local failed = `failed' + 1
}

capture assert migration_out_dt == . if id == 1
if _rc == 0 {
    display as result "[PASS] Long format person 1: no censoring date (temporary emigration)"
    local passed = `passed' + 1
}
else {
    summarize migration_out_dt if id == 1, format
    display as error "[FAIL] Long format person 1: has censoring date but emigration was temporary"
    local failed = `failed' + 1
}

capture assert migration_out_dt == td(01jun2020) if id == 2
if _rc == 0 {
    display as result "[PASS] Long format person 2: correct censoring date for permanent emigration"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Long format person 2: wrong censoring date for permanent emigration"
    local failed = `failed' + 1
}

capture assert migration_out_dt == . if id == 3
if _rc == 0 {
    display as result "[PASS] Long format person 3: no censoring date (temporary emigration)"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Long format person 3: has censoring date but emigration was temporary"
    local failed = `failed' + 1
}

quietly count if id == 4
capture assert r(N) == 1
if _rc == 0 {
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Long format person 4: missing from final dataset"
    local failed = `failed' + 1
}

capture assert migration_out_dt == . if id == 4
if _rc == 0 {
    display as result "[PASS] Long format person 4: retained with no censoring date"
    local passed = `passed' + 1
}
else {
    display as error "[FAIL] Long format person 4: has unexpected censoring date"
    local failed = `failed' + 1
}

* --- Summary ---
display _newline "=== TEST SUMMARY ==="
display "Passed: `passed'"
display "Failed: `failed'"
display "Total:  " `passed' + `failed'

if `failed' > 0 {
    display as error _newline "FAILED: `failed' test(s) failed"
    exit 9
}
else {
    display as result _newline "ALL TESTS PASSED"
}
