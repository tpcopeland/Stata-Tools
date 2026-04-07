* test_migrations_keepimmigrants.do
* QA tests for migrations keepimmigrants option
*
* Tests:
*   K1:  keepimmigrants includes Type 2 individuals (not excluded)
*   K2:  migration_in_dt generated with correct immigration date
*   K3:  migration_in_dt is missing for non-Type-2 individuals
*   K4:  r(N_excluded_inmigration) = 0 with keepimmigrants
*   K5:  r(N_included_inmigration) correct count
*   K6:  r(N_included_inmigration) = 0 without keepimmigrants
*   K7:  Final sample size larger with keepimmigrants than without
*   K8:  Summary line shows "Included" not "Excluded"
*   K9:  migration_in_dt not generated without keepimmigrants
*   K10: Backward compatibility — without option, behavior unchanged
*   K11: keepimmigrants with no Type 2 individuals — no error
*   K12: keepimmigrants with empty migration file — both date vars created
*   K13: keepimmigrants with saveexclude — Type 2 not in exclusion file
*   K14: keepimmigrants with savecensor — runs without error
*   K15: Pre-existing migration_in_dt → error 110
*   K16: migration_in_dt variable type is long
*   K17: migration_in_dt has correct date format
*   K18: Exclusion sum consistency with keepimmigrants
*   K19: Multiple Type 2 immigrants — all included with correct dates
*   K20: keepimmigrants + minresidence — no interaction (different populations)
*   K21: Type 1 and Type 3 still excluded with keepimmigrants
*   K22: Varabbrev restored on success with keepimmigrants
*   K23: Varabbrev restored on error with keepimmigrants
*   K24: Data preservation — original vars unchanged by keepimmigrants
*   K25: keepimmigrants with verbose — runs without error

clear all
set more off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall setools
net install setools, from("`pkg_dir'") replace

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


* === Test Data ===
* Reuse the standard 5-person test data from test_setools.do
* Person 1: no migration record (stays)
* Person 2: emigrated before start, never returned → Type 1 exclusion
* Person 3: immigrated after start → Type 2 (keepimmigrants target)
* Person 4: emigrated during study → censored
* Person 5: temp emigration + return, then permanent → censored at permanent

local data_dir "`qa_dir'/data"

* 21185 = td(01jan2018)
clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
5 21185
end
format study_start %td
tempfile master5
save `master5'

clear
input long id double(in_1 out_1 in_2 out_2)
2 . 20999 . .
3 21244 . . .
4 . 21366 . .
5 . 21244 21336 21427
end
format in_1 out_1 in_2 out_2 %td
tempfile mig5
save `mig5'


**# K1: keepimmigrants includes Type 2 individuals

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
qui count if id == 3
local k1_present = r(N)
local t = (`k1_present' == 1)
run_test "K1: Type 2 person (id=3) retained with keepimmigrants" `t'


**# K2: migration_in_dt has correct immigration date

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
qui summarize migration_in_dt if id == 3
* Person 3 immigrated at 21244 = td(20feb2018)
local t = (r(mean) == 21244)
run_test "K2: migration_in_dt = 21244 for person 3" `t'


**# K3: migration_in_dt is missing for non-Type-2 individuals

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
qui count if !missing(migration_in_dt) & id != 3
local t = (r(N) == 0)
run_test "K3: migration_in_dt missing for non-Type-2 individuals" `t'


**# K4: r(N_excluded_inmigration) = 0 with keepimmigrants

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
local t = (r(N_excluded_inmigration) == 0)
run_test "K4: r(N_excluded_inmigration) = 0 with keepimmigrants" `t'


**# K5: r(N_included_inmigration) correct count

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
local t = (r(N_included_inmigration) == 1)
run_test "K5: r(N_included_inmigration) = 1" `t'


**# K6: r(N_included_inmigration) = 0 without keepimmigrants

use `master5', clear
migrations, migfile("`mig5'")
local t = (r(N_included_inmigration) == 0)
run_test "K6: r(N_included_inmigration) = 0 without option" `t'


**# K7: Final sample larger with keepimmigrants

use `master5', clear
migrations, migfile("`mig5'")
local n_without = r(N_final)

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
local n_with = r(N_final)

local t = (`n_with' == `n_without' + 1)
run_test "K7: final sample +1 with keepimmigrants (4 vs 3)" `t'


**# K8: Summary displays "Included" (log inspection)

use `master5', clear
log using "`qa_dir'/_test_keepimm_log.log", text replace
migrations, migfile("`mig5'") keepimmigrants
log close
* Read log for "Included"
capture file open fh using "`qa_dir'/_test_keepimm_log.log", read text
local found_included = 0
if _rc == 0 {
    file read fh line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Included (immigration after study start)") > 0 {
            local found_included = 1
        }
        file read fh line
    }
    file close fh
}
capture erase "`qa_dir'/_test_keepimm_log.log"
local t = (`found_included' == 1)
run_test "K8: summary shows 'Included' line with keepimmigrants" `t'


**# K9: migration_in_dt NOT generated without keepimmigrants

use `master5', clear
migrations, migfile("`mig5'")
capture confirm variable migration_in_dt
local t = (_rc != 0)
run_test "K9: migration_in_dt absent without keepimmigrants" `t'


**# K10: Backward compatibility — without option, identical behavior

use `master5', clear
migrations, migfile("`mig5'")
local bc_excl_total = r(N_excluded_total)
local bc_excl_inmig = r(N_excluded_inmigration)
local bc_final = r(N_final)
local bc_censor = r(N_censored)
* Original behavior: 2 excluded (type 1 + type 2), 3 remain
local t = (`bc_excl_total' == 2 & `bc_excl_inmig' == 1 & `bc_final' == 3 & `bc_censor' == 2)
run_test "K10: without option — same as v1.2.1 behavior" `t'


**# K11: keepimmigrants with no Type 2 individuals

* Create data with only Type 1 exclusion (no immigration-after-start)
clear
input long id double study_start
1 21185
2 21185
end
format study_start %td
tempfile k11_cohort
save `k11_cohort'

clear
input long id double(in_1 out_1)
2 . 20999
end
format in_1 out_1 %td
tempfile k11_mig
save `k11_mig'

use `k11_cohort', clear
capture noisily migrations, migfile("`k11_mig'") keepimmigrants
local k11_rc = _rc
local k11_incl = r(N_included_inmigration)
local t = (`k11_rc' == 0 & `k11_incl' == 0)
run_test "K11: keepimmigrants with no Type 2 — no error, count=0" `t'


**# K12: keepimmigrants with no cohort members in migration file

clear
input long id double study_start
99 21185
end
format study_start %td
tempfile k12_cohort
save `k12_cohort'

use `k12_cohort', clear
capture noisily migrations, migfile("`mig5'") keepimmigrants
local k12_rc = _rc
* Both date vars should exist
capture confirm variable migration_out_dt
local k12_out = (_rc == 0)
capture confirm variable migration_in_dt
local k12_in = (_rc == 0)
local t = (`k12_rc' == 0 & `k12_out' & `k12_in')
run_test "K12: no cohort match — both date vars created (all missing)" `t'


**# K13: keepimmigrants with saveexclude — Type 2 not in file

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants ///
    saveexclude("`qa_dir'/data/_test_keepimm_excl.dta") replace
* Load exclusion file and check person 3 (Type 2) is NOT there
preserve
use "`qa_dir'/data/_test_keepimm_excl.dta", clear
qui count if id == 3
local k13_p3 = r(N)
qui count
local k13_total = r(N)
restore
* Person 2 (Type 1) should be excluded, person 3 (Type 2) should NOT
local t = (`k13_p3' == 0 & `k13_total' == 1)
run_test "K13: saveexclude does not contain Type 2 with keepimmigrants" `t'


**# K14: keepimmigrants with savecensor — runs without error

use `master5', clear
capture noisily migrations, migfile("`mig5'") keepimmigrants ///
    savecensor("`qa_dir'/data/_test_keepimm_cens.dta") replace
local t = (_rc == 0)
run_test "K14: savecensor with keepimmigrants runs" `t'


**# K15: Pre-existing migration_in_dt → error 110

use `master5', clear
gen double migration_in_dt = .
capture migrations, migfile("`mig5'") keepimmigrants
local t = (_rc == 110)
run_test "K15: pre-existing migration_in_dt → rc 110" `t'


**# K16: migration_in_dt variable type is long

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
local vtype: type migration_in_dt
local t = ("`vtype'" == "long")
run_test "K16: migration_in_dt type is long" `t'


**# K17: migration_in_dt has date format

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
local vfmt: format migration_in_dt
local t = (strpos("`vfmt'", "%td") > 0)
run_test "K17: migration_in_dt has %td format" `t'


**# K18: Exclusion sum consistency with keepimmigrants

use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
* With keepimmigrants: excl_inmig=0, so total = emig + 0 + abroad + minres
local sum = r(N_excluded_emigrated) + r(N_excluded_inmigration) + r(N_excluded_abroad) + r(N_excluded_minresidence)
local t = (r(N_excluded_total) == `sum')
run_test "K18: exclusion sum consistency with keepimmigrants" `t'


**# K19: Multiple Type 2 immigrants — all included with correct dates

clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
end
format study_start %td
tempfile k19_cohort
save `k19_cohort'

* Person 1: native (no record)
* Person 2: immigrates td(15mar2018) = 21258
* Person 3: immigrates td(01jul2018) = 21366
* Person 4: emigrated before start, never returned
clear
input long id double(in_1 out_1)
2 21258 .
3 21366 .
4 . 20800
end
format in_1 out_1 %td
tempfile k19_mig
save `k19_mig'

use `k19_cohort', clear
migrations, migfile("`k19_mig'") keepimmigrants
local k19_incl = r(N_included_inmigration)
local k19_final = r(N_final)
qui summarize migration_in_dt if id == 2
local k19_dt2 = r(mean)
qui summarize migration_in_dt if id == 3
local k19_dt3 = r(mean)

local t1 = (`k19_incl' == 2)
run_test "K19a: 2 immigrants included" `t1'
local t2 = (`k19_final' == 3)
run_test "K19b: final sample = 3 (persons 1, 2, 3)" `t2'
local t3 = (`k19_dt2' == 21258)
run_test "K19c: person 2 migration_in_dt = 21258" `t3'
local t4 = (`k19_dt3' == 21366)
run_test "K19d: person 3 migration_in_dt = 21366" `t4'


**# K20: keepimmigrants + minresidence — no interaction

clear
input long id double study_start
1 21185
2 21185
3 21185
end
format study_start %td
tempfile k20_cohort
save `k20_cohort'

* Person 1: immigrated 100 days before start → minresidence exclusion
* Person 2: immigrated after start → Type 2 (kept by keepimmigrants)
* Person 3: native, no record
clear
input long id double(in_1 out_1)
1 21085 .
2 21244 .
end
format in_1 out_1 %td
tempfile k20_mig
save `k20_mig'

use `k20_cohort', clear
migrations, migfile("`k20_mig'") keepimmigrants minresidence(365)
local k20_minres = r(N_excluded_minresidence)
local k20_incl = r(N_included_inmigration)
local k20_final = r(N_final)
* Person 1: excluded by minresidence (100 < 365)
* Person 2: included by keepimmigrants (Type 2)
* Person 3: retained (no migration record)
local t1 = (`k20_minres' == 1)
run_test "K20a: minresidence still excludes person 1" `t1'
local t2 = (`k20_incl' == 1)
run_test "K20b: keepimmigrants includes person 2" `t2'
local t3 = (`k20_final' == 2)
run_test "K20c: final = 2 (persons 2 and 3)" `t3'


**# K21: Type 1 and Type 3 still excluded with keepimmigrants

clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
end
format study_start %td
tempfile k21_cohort
save `k21_cohort'

* Person 1: native (retained)
* Person 2: emigrated before start, never returned → Type 1
* Person 3: abroad at baseline (emigrated before, returned after) → Type 3
*           in_1/out_1 must be at same index for Type 3 detection
* Person 4: immigrated after start → Type 2 (kept by keepimmigrants)
clear
input long id double(in_1 out_1 in_2 out_2)
2 . 20800 . .
3 21300 20800 . .
4 21300 . . .
end
format in_1 out_1 in_2 out_2 %td
tempfile k21_mig
save `k21_mig'

use `k21_cohort', clear
migrations, migfile("`k21_mig'") keepimmigrants
local k21_emig = r(N_excluded_emigrated)
local k21_abroad = r(N_excluded_abroad)
local k21_inmig = r(N_excluded_inmigration)
local k21_incl = r(N_included_inmigration)
local k21_final = r(N_final)
qui count if id == 2
local k21_p2 = r(N)
qui count if id == 3
local k21_p3 = r(N)
qui count if id == 4
local k21_p4 = r(N)

local t1 = (`k21_emig' == 1 & `k21_p2' == 0)
run_test "K21a: Type 1 (person 2) still excluded" `t1'
local t2 = (`k21_abroad' == 1 & `k21_p3' == 0)
run_test "K21b: Type 3 (person 3) still excluded" `t2'
local t3 = (`k21_inmig' == 0 & `k21_incl' == 1 & `k21_p4' == 1)
run_test "K21c: Type 2 (person 4) included" `t3'
local t4 = (`k21_final' == 2)
run_test "K21d: final = 2 (persons 1 and 4)" `t4'


**# K22: Varabbrev restored on success with keepimmigrants

set varabbrev on
use `master5', clear
migrations, migfile("`mig5'") keepimmigrants
local t = (c(varabbrev) == "on")
run_test "K22: varabbrev restored after success" `t'


**# K23: Varabbrev restored on error with keepimmigrants

set varabbrev on
use `master5', clear
gen double migration_in_dt = .
capture noisily migrations, migfile("`mig5'") keepimmigrants
local t = (c(varabbrev) == "on")
run_test "K23: varabbrev restored after error" `t'


**# K24: Data preservation — original vars unchanged

use `master5', clear
gen double extra_var = _n * 100
local orig_N = _N
local orig_v1 = id[1]
local orig_v2 = study_start[1]
local orig_e = extra_var[3]
migrations, migfile("`mig5'") keepimmigrants
* N changes because Type 1 is excluded, but remaining row values intact
local t1 = (id[1] == `orig_v1')
run_test "K24a: id values unchanged" `t1'
local t2 = (study_start[1] == `orig_v2')
run_test "K24b: study_start values unchanged" `t2'
capture confirm variable extra_var
local t3 = (_rc == 0)
run_test "K24c: extra_var preserved" `t3'


**# K25: keepimmigrants with verbose

use `master5', clear
capture noisily migrations, migfile("`mig5'") keepimmigrants verbose
local t = (_rc == 0)
run_test "K25: verbose + keepimmigrants runs without error" `t'


* === Cleanup ===
capture erase "`qa_dir'/data/_test_keepimm_excl.dta"
capture erase "`qa_dir'/data/_test_keepimm_cens.dta"


* === SUMMARY ===
display _newline "=== KEEPIMMIGRANTS TEST SUMMARY ==="
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
