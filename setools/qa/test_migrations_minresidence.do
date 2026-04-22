* test_migrations_minresidence.do
* QA tests for migrations minresidence() option
*
* Tests:
*   R1: minresidence(0) — disabled, no effect
*   R2: Born in Sweden (no immigration) — always passes
*   R3: Immigrated 365+ days before start — passes minresidence(365)
*   R4: Immigrated 100 days before start — excluded by minresidence(365)
*   R5: Boundary — exactly minresidence days — passes (uses <, not <=)
*   R6: Boundary — one day short — excluded
*   R7: Interaction with other exclusions — minresidence doesn't double-count
*   R8: Mixed cohort — correct counts
*   R9: Long-format migration data respects minresidence()

clear all
set more off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall setools
net install setools, from("`pkg_dir'")

global passed = 0
global failed = 0

capture program drop run_test
program define run_test
    args name result
    if `result' {
        display as result "  [PASS] `name'"
        global passed = $passed + 1
    }
    else {
        display as error "  [FAIL] `name'"
        global failed = $failed + 1
    }
end


**# R1: minresidence(0) — disabled by default

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r1_cohort
save `r1_cohort'

clear
set obs 1
gen long id = 1
gen long in_1 = td(01dec2017)
gen long out_1 = .
format in_1 out_1 %td
tempfile r1_mig
save `r1_mig'

* Immigrated 31 days before start — no minresidence check
use `r1_cohort', clear
migrations, migfile("`r1_mig'")
local r1_minres = r(N_excluded_minresidence)
qui count if id == 1
local r1_present = r(N)
local t = (`r1_present' == 1 & `r1_minres' == 0)
run_test "R1: minresidence(0) disabled — person retained" `t'


**# R2: Born in Sweden — no immigration record, always passes

clear
set obs 2
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
tempfile r2_cohort
save `r2_cohort'

* Only person 2 has migration data (emigrates permanently)
clear
set obs 1
gen long id = 2
gen long in_1 = .
gen long out_1 = td(01jun2020)
format in_1 out_1 %td
tempfile r2_mig
save `r2_mig'

use `r2_cohort', clear
migrations, migfile("`r2_mig'") minresidence(365)
local r2_minres = r(N_excluded_minresidence)
qui count if id == 1
local r2_p1 = r(N)
local t = (`r2_p1' == 1 & `r2_minres' == 0)
run_test "R2: no migration record (born in Sweden) — passes minresidence" `t'


**# R3: Immigrated 365+ days before start — passes minresidence(365)

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r3_cohort
save `r3_cohort'

clear
set obs 1
gen long id = 1
gen long in_1 = td(01jan2016)
gen long out_1 = .
format in_1 out_1 %td
tempfile r3_mig
save `r3_mig'

* Immigrated 730 days before start
use `r3_cohort', clear
migrations, migfile("`r3_mig'") minresidence(365)
local r3_minres = r(N_excluded_minresidence)
qui count if id == 1
local r3_present = r(N)
local t = (`r3_present' == 1 & `r3_minres' == 0)
run_test "R3: immigrated 730 days before start — passes minresidence(365)" `t'


**# R4: Immigrated 100 days before start — excluded by minresidence(365)

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r4_cohort
save `r4_cohort'

clear
set obs 1
gen long id = 1
gen long in_1 = td(23sep2017)
gen long out_1 = .
format in_1 out_1 %td
tempfile r4_mig
save `r4_mig'

* Immigrated 100 days before start (01jan2018 - 23sep2017 = 100 days)
use `r4_cohort', clear
migrations, migfile("`r4_mig'") minresidence(365)
local r4_minres = r(N_excluded_minresidence)
qui count if id == 1
local r4_present = r(N)
local t = (`r4_present' == 0 & `r4_minres' == 1)
run_test "R4: immigrated 100 days before start — excluded by minresidence(365)" `t'


**# R5: Boundary — exactly minresidence days — passes

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r5_cohort
save `r5_cohort'

clear
set obs 1
gen long id = 1
* study_start - 365 = td(01jan2017)
gen long in_1 = td(01jan2017)
gen long out_1 = .
format in_1 out_1 %td
tempfile r5_mig
save `r5_mig'

* Exactly 365 days: condition is < 365 → FALSE → passes
use `r5_cohort', clear
migrations, migfile("`r5_mig'") minresidence(365)
local r5_minres = r(N_excluded_minresidence)
qui count if id == 1
local r5_present = r(N)
local t = (`r5_present' == 1 & `r5_minres' == 0)
run_test "R5: exactly 365 days residence — passes (boundary)" `t'


**# R6: Boundary — one day short — excluded

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r6_cohort
save `r6_cohort'

clear
set obs 1
gen long id = 1
* study_start - 364 = td(02jan2017)
gen long in_1 = td(02jan2017)
gen long out_1 = .
format in_1 out_1 %td
tempfile r6_mig
save `r6_mig'

* 364 days: condition is < 365 → TRUE → excluded
use `r6_cohort', clear
migrations, migfile("`r6_mig'") minresidence(365)
local r6_minres = r(N_excluded_minresidence)
qui count if id == 1
local r6_present = r(N)
local t = (`r6_present' == 0 & `r6_minres' == 1)
run_test "R6: 364 days residence — excluded (one day short)" `t'


**# R7: Interaction — person excluded by type 1 is not also counted as minresidence

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r7_cohort
save `r7_cohort'

clear
set obs 1
gen long id = 1
* Emigrated before start, never returned — type 1 exclusion
gen long in_1 = td(01nov2017)
gen long out_1 = td(01dec2017)
format in_1 out_1 %td
tempfile r7_mig
save `r7_mig'

use `r7_cohort', clear
migrations, migfile("`r7_mig'") minresidence(365)
local r7_emig = r(N_excluded_emigrated)
local r7_minres = r(N_excluded_minresidence)
* Should be excluded by type 1, NOT by minresidence
local t = (`r7_emig' == 1 & `r7_minres' == 0)
run_test "R7: type 1 exclusion — not double-counted as minresidence" `t'


**# R8: Mixed cohort — correct counts across all exclusion types

clear
input long id
1
2
3
4
5
end
gen long study_start = td(01jan2018)
format study_start %td
tempfile r8_cohort
save `r8_cohort'

clear
set obs 5
gen long id = _n
gen long in_1 = .
gen long out_1 = .
gen long in_2 = .
gen long out_2 = .
* Person 1: native, emigrates 2020 permanent → censor
replace out_1 = td(01jun2020) if id == 1
* Person 2: immigrated 364 days before start → minresidence exclusion
replace in_1 = td(02jan2017) if id == 2
* Person 3: immigrated 2015 → passes minresidence, temp emigration
replace in_1 = td(01mar2015) if id == 3
replace out_1 = td(01jun2020) if id == 3
replace in_2 = td(01jan2021) if id == 3
* Person 4: emigrated 2016, no return → type 1
replace out_1 = td(01jan2016) if id == 4
* Person 5: immigrated 364 days before start, emigrates 2020 permanent
replace in_1 = td(02jan2017) if id == 5
replace out_1 = td(01jun2020) if id == 5
format in_* out_* %td
tempfile r8_mig
save `r8_mig'

use `r8_cohort', clear
migrations, migfile("`r8_mig'") minresidence(365)
local r8_emig = r(N_excluded_emigrated)
local r8_minres = r(N_excluded_minresidence)
local r8_total = r(N_excluded_total)
local r8_final = r(N_final)
local r8_censor = r(N_censored)

* Person 1: native, emigrates 2020 → retained with censoring date
* Person 2: immigrated 364d before start → excluded by minresidence
* Person 3: immigrated 2015 (1096d) → passes, temp emigration → no censor
* Person 4: emigrated 2016, no return → excluded type 1
* Person 5: immigrated 364d before start → excluded by minresidence
local t1 = (`r8_emig' == 1)
run_test "R8a: 1 type-1 exclusion" `t1'
local t2 = (`r8_minres' == 2)
run_test "R8b: 2 minresidence exclusions" `t2'
local t3 = (`r8_final' == 2)
run_test "R8c: final sample = 2 (persons 1 and 3)" `t3'
local t4 = (`r8_censor' == 1)
run_test "R8d: 1 censoring date (person 1)" `t4'

* Verify persons 1 and 3 are in the final data
qui count if id == 1
local p1 = (r(N) == 1)
qui count if id == 3
local p3 = (r(N) == 1)
run_test "R8e: person 1 retained" `p1'
run_test "R8f: person 3 retained" `p3'


**# R9: Long-format migration data respects minresidence()

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile r9_cohort
save `r9_cohort'

clear
set obs 1
gen long id = 1
gen long event_date = td(23sep2017)
gen str3 event_type = "Inv"
format event_date %td
tempfile r9_mig
save `r9_mig'

use `r9_cohort', clear
migrations, migfile("`r9_mig'") minresidence(365)
local r9_minres = r(N_excluded_minresidence)
qui count if id == 1
local r9_present = r(N)
local t = (`r9_present' == 0 & `r9_minres' == 1)
run_test "R9: long-format immigration 100 days before start -> minresidence exclusion" `t'


* === SUMMARY ===
display _newline "=== MINRESIDENCE TEST SUMMARY ==="
display "Passed: $passed"
display "Failed: $failed"
display "Total:  " $passed + $failed

if $failed > 0 {
    display as error _newline "FAILED: $failed test(s) failed"
    exit 9
}
else {
    display as result _newline "ALL TESTS PASSED"
}
