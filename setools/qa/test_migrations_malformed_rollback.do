* test_migrations_malformed_rollback.do
* Migrations-only adversarial tests for malformed files, no-match/no-event paths,
* duplicate long events, exact return counts, and save rollback.
*
* Run from setools/qa:
*     stata-mp -b do test_migrations_malformed_rollback.do

clear all
version 16.0
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_test
program define run_test
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  [PASS] `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  [FAIL] `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures `"${gs_failures} `test_name'"'
    }
end

**# Shared fixtures

tempfile master valid_wide

clear
input long id long study_start
1 21185
2 21185
3 21185
end
format study_start %td
save `master', replace

clear
input long id long(in_1 out_1 in_2 out_2)
1 .     21366 .     .
2 21244 .     .     .
3 .     20999 .     .
end
format in_1 out_1 in_2 out_2 %td
save `valid_wide', replace

**# Malformed wide-format files

tempfile malformed_wide duplicate_wide string_wide

clear
input long id long in_1
1 21244
end
format in_1 %td
save `malformed_wide', replace

set varabbrev on
use `master', clear
capture noisily migrations, migfile("`malformed_wide'")
local rc = _rc
local ok = (`rc' == 111 & "`c(varabbrev)'" == "on")
run_test "M1: wide file with in_1 but no out_1 is rejected and restores varabbrev" `ok'

clear
input long id long(in_1 out_1)
1 21244 .
1 21300 .
end
format in_1 out_1 %td
save `duplicate_wide', replace

set varabbrev on
use `master', clear
capture noisily migrations, migfile("`duplicate_wide'")
local rc = _rc
local ok = (`rc' == 459 & "`c(varabbrev)'" == "on")
run_test "M2: duplicate IDs in wide migration file -> rc 459 and varabbrev restored" `ok'

clear
input long id str10 in_1 long out_1
1 "2018-02-20" .
end
format out_1 %td
save `string_wide', replace

use `master', clear
capture noisily migrations, migfile("`string_wide'")
local ok = (_rc == 109)
run_test "M3: string wide-format migration date -> rc 109" `ok'

**# Malformed long-format files

tempfile long_no_id long_missing_type long_string_date long_reserved_out

clear
input long person_id long event_date str3 event_type
1 21244 "Inv"
end
format event_date %td
save `long_no_id', replace

use `master', clear
capture noisily migrations, migfile("`long_no_id'")
local ok = (_rc == 111)
run_test "M4: long file missing idvar -> rc 111" `ok'

clear
input long id long event_date
1 21244
end
format event_date %td
save `long_missing_type', replace

use `master', clear
capture noisily migrations, migfile("`long_missing_type'")
local ok = (_rc == 111)
run_test "M5: long file missing event_type is unrecognized -> rc 111" `ok'

clear
input long id str10 event_date str3 event_type
1 "2018-02-20" "Inv"
end
save `long_string_date', replace

use `master', clear
capture noisily migrations, migfile("`long_string_date'")
local ok = (_rc == 109)
run_test "M6: string long-format event_date -> rc 109" `ok'

clear
input long id long event_date str3 event_type long out_
1 21244 "Inv" .
end
format event_date out_ %td
save `long_reserved_out', replace

use `master', clear
capture noisily migrations, migfile("`long_reserved_out'")
local ok = (_rc == 110)
run_test "M7: reserved out_ in long-format migration file -> rc 110" `ok'

**# No-event and no-match branches

tempfile empty_long noevent_excl noevent_cens nomatch_wide nomatch_excl nomatch_cens

clear
set obs 0
gen long id = .
gen long event_date = .
gen str3 event_type = ""
format event_date %td
save `empty_long', replace

use `master', clear
migrations, migfile("`empty_long'") saveexclude("`noevent_excl'") ///
    savecensor("`noevent_cens'") replace
local ok = (r(N_excluded_total) == 0 & r(N_censored) == 0 & ///
    r(N_final) == 3 & _N == 3)
quietly count if !missing(migration_out_dt)
local ok = (`ok' & r(N) == 0)
run_test "M8: empty long-format file retains cohort with exact zero returns" `ok'

preserve
use `noevent_excl', clear
capture confirm variable id
local noevent_id = (_rc == 0)
capture confirm variable exclude_reason
local noevent_reason = (_rc == 0)
local ok = (_N == 0 & `noevent_id' & `noevent_reason')
restore
run_test "M9: empty long saveexclude has empty id/exclude_reason schema" `ok'

preserve
use `noevent_cens', clear
capture confirm variable id
local noevent_cid = (_rc == 0)
capture confirm variable migration_out_dt
local noevent_out = (_rc == 0)
local ok = (_N == 0 & `noevent_cid' & `noevent_out')
restore
run_test "M10: empty long savecensor has empty id/migration_out_dt schema" `ok'

clear
input long id long(in_1 out_1)
99 . 21366
end
format in_1 out_1 %td
save `nomatch_wide', replace

use `master', clear
migrations, migfile("`nomatch_wide'") saveexclude("`nomatch_excl'") ///
    savecensor("`nomatch_cens'") replace
local ok = (r(N_excluded_total) == 0 & r(N_censored) == 0 & ///
    r(N_final) == 3 & _N == 3)
quietly count if !missing(migration_out_dt)
local ok = (`ok' & r(N) == 0)
run_test "M11: migration file with no cohort matches has exact zero returns" `ok'

preserve
use `nomatch_excl', clear
capture confirm variable exclude_reason
local ok = (_N == 0 & _rc == 0)
restore
run_test "M12: no-match saveexclude is empty with exclude_reason" `ok'

preserve
use `nomatch_cens', clear
capture confirm variable migration_out_dt
local ok = (_N == 0 & _rc == 0)
restore
run_test "M13: no-match savecensor is empty with migration_out_dt" `ok'

**# Duplicate long event rows

tempfile dup_out_long dup_out_cens dup_in_long dup_in_excl

clear
input long id long event_date str3 event_type
1 21366 "Utv"
1 21366 "Utv"
end
format event_date %td
save `dup_out_long', replace

use `master', clear
keep if id == 1
migrations, migfile("`dup_out_long'") savecensor("`dup_out_cens'") replace
local ok = (r(N_excluded_total) == 0 & r(N_censored) == 1 & ///
    r(N_final) == 1 & _N == 1 & migration_out_dt[1] == 21366)
run_test "M14: duplicate long emigration rows produce one censoring date" `ok'

preserve
use `dup_out_cens', clear
local ok = (_N == 1 & id[1] == 1 & migration_out_dt[1] == 21366)
restore
run_test "M15: duplicate long emigration rows export one savecensor row" `ok'

clear
input long id long event_date str3 event_type
1 21244 "Inv"
1 21244 "Inv"
end
format event_date %td
save `dup_in_long', replace

use `master', clear
keep if id == 1
migrations, migfile("`dup_in_long'") saveexclude("`dup_in_excl'") replace
local ok = (r(N_excluded_inmigration) == 1 & r(N_excluded_total) == 1 & ///
    r(N_final) == 0 & _N == 0)
run_test "M16: duplicate long immigration rows exclude once by exact return counts" `ok'

preserve
use `dup_in_excl', clear
local ok = (_N == 1 & id[1] == 1 & ///
    exclude_reason[1] == "Immigration after study start (not in Sweden at baseline)")
restore
run_test "M17: duplicate long immigration rows export one saveexclude row" `ok'

**# Save-option validation and rollback

tempfile existing_excl existing_cens

clear
set obs 1
gen byte sentinel = 17
save `existing_excl', replace

clear
set obs 1
gen byte sentinel = 18
save `existing_cens', replace

use `master', clear
capture noisily migrations, migfile("`valid_wide'") saveexclude("`existing_excl'")
local ok = (_rc == 602)
run_test "M18: existing saveexclude without replace -> rc 602" `ok'

use `master', clear
capture noisily migrations, migfile("`valid_wide'") savecensor("`existing_cens'")
local ok = (_rc == 602)
run_test "M19: existing savecensor without replace -> rc 602" `ok'

use `master', clear
capture noisily migrations, migfile("`valid_wide'") saveexclude("bad;file.dta")
local ok = (_rc == 198)
run_test "M20: saveexclude invalid path characters -> rc 198" `ok'

use `master', clear
capture noisily migrations, migfile("`valid_wide'") savecensor("bad;file.dta")
local ok = (_rc == 198)
run_test "M21: savecensor invalid path characters -> rc 198" `ok'

use `master', clear
capture noisily migrations, migfile("bad;file.dta")
local ok = (_rc == 198)
run_test "M22: migfile invalid path characters -> rc 198" `ok'

use `master', clear
capture noisily migrations, migfile("`valid_wide'") minresidence(-1)
local ok = (_rc == 198)
run_test "M23: negative minresidence -> rc 198" `ok'

tempfile rollback_excl
clear
set obs 1
gen byte sentinel = 91
save `rollback_excl', replace

local bad_cens "`c(tmpdir)'/setools_missing_rollback_`c(processid)'/censor.dta"
set varabbrev on
use `master', clear
capture noisily migrations, migfile("`valid_wide'") ///
    saveexclude("`rollback_excl'") savecensor("`bad_cens'") replace
local rc = _rc
local data_ok = (`rc' != 0 & _N == 3 & "`c(varabbrev)'" == "on")
capture confirm variable migration_out_dt
local data_ok = (`data_ok' & _rc != 0)
preserve
use `rollback_excl', clear
local rollback_ok = (_N == 1 & sentinel[1] == 91)
restore
local ok = (`data_ok' & `rollback_ok')
run_test "M24: second-save failure restores data, varabbrev, and previous saveexclude" `ok'

**# Summary

display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}
display "RESULT: test_migrations_malformed_rollback tests=" scalar(gs_ntest) ///
    " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)

if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
}

do "`qa_dir'/_setools_qa_common.do" teardown
