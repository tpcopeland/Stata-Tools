* validation_migrations_adversarial_boundaries.do
* Migrations-only known-answer validation for adversarial state boundaries.
*
* Run from setools/qa:
*     stata-mp -b do validation_migrations_adversarial_boundaries.do

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

capture program drop run_val
program define run_val
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

capture program drop _check_complex_migrations
program define _check_complex_migrations
    args source_name

    local ok_counts = (r(N_excluded_emigrated) == 1 & ///
        r(N_excluded_inmigration) == 0 & ///
        r(N_excluded_abroad) == 1 & ///
        r(N_excluded_minresidence) == 2 & ///
        r(N_excluded_total) == 4 & ///
        r(N_included_inmigration) == 1 & ///
        r(N_censored) == 4 & ///
        r(N_final) == 10 & ///
        _N == 10)
    run_val "`source_name': exact return counts for mixed migration states" `ok_counts'

    sort id
    local ok_ids = (_N == 10 & id[1] == 1 & id[2] == 4 & ///
        id[3] == 6 & id[4] == 7 & id[5] == 8 & ///
        id[6] == 9 & id[7] == 10 & id[8] == 11 & ///
        id[9] == 12 & id[10] == 13)
    run_val "`source_name': exact final cohort membership" `ok_ids'

    quietly summarize migration_in_dt if id == 4, meanonly
    local ok_in = (r(N) == 1 & r(mean) == td(20feb2018))
    quietly count if id != 4 & !missing(migration_in_dt)
    local ok_in = (`ok_in' & r(N) == 0)
    run_val "`source_name': keepimmigrants records only the late immigrant entry date" `ok_in'

    local ok_out = 1
    quietly summarize migration_out_dt if id == 7, meanonly
    if r(N) != 1 | r(mean) != td(01jun2019) local ok_out = 0
    quietly summarize migration_out_dt if id == 9, meanonly
    if r(N) != 1 | r(mean) != td(01may2021) local ok_out = 0
    quietly summarize migration_out_dt if id == 11, meanonly
    if r(N) != 1 | r(mean) != td(01jun2019) local ok_out = 0
    quietly summarize migration_out_dt if id == 12, meanonly
    if r(N) != 1 | r(mean) != td(01jun2019) local ok_out = 0
    quietly count if inlist(id, 1, 4, 6, 8, 10, 13) & !missing(migration_out_dt)
    if r(N) != 0 local ok_out = 0
    run_val "`source_name': exact permanent-emigration censoring dates" `ok_out'

    quietly count if id == 8 & missing(migration_out_dt)
    local ok_temp = (r(N) == 1)
    quietly count if id == 10 & missing(migration_out_dt)
    local ok_temp = (`ok_temp' & r(N) == 1)
    run_val "`source_name': overlapping emigration spells with later return are not censored" `ok_temp'

    quietly count if id == 11 & migration_out_dt == td(01jun2019)
    local ok_same_day = (r(N) == 1)
    run_val "`source_name': same-day in/out after start censors on that date" `ok_same_day'

    local fmt_out : format migration_out_dt
    local typ_out : type migration_out_dt
    local fmt_in : format migration_in_dt
    local typ_in : type migration_in_dt
    local ok_vars = ("`typ_out'" == "long" & strpos("`fmt_out'", "%td") > 0 & ///
        "`typ_in'" == "long" & strpos("`fmt_in'", "%td") > 0)
    run_val "`source_name': generated date variables have long type and %td format" `ok_vars'
end

**# Build hand-computable cohort and migration files

tempfile master mig_wide mig_long

clear
set obs 14
gen long id = _n
gen long study_start = td(01jan2018)
gen str8 source_tag = "kept"
format study_start %td
save `master', replace

clear
set obs 13
gen long id = _n + 1
gen long in_1 = .
gen long out_1 = .
gen long in_2 = .
gen long out_2 = .

replace out_1 = td(01dec2017) if id == 2
replace out_1 = td(01dec2017) if id == 3
replace in_1 = td(01feb2018) if id == 3
replace in_1 = td(20feb2018) if id == 4
replace in_1 = td(02jan2017) if id == 5
replace in_1 = td(01jan2017) if id == 6
replace out_1 = td(01jun2019) if id == 7
replace in_1 = td(01jan2010) if id == 8
replace out_1 = td(01jun2019) if id == 8
replace in_2 = td(01aug2019) if id == 8
replace in_1 = td(01jan2010) if id == 9
replace out_1 = td(01jun2019) if id == 9
replace in_2 = td(01aug2019) if id == 9
replace out_2 = td(01may2021) if id == 9
replace in_1 = td(01jan2010) if id == 10
replace out_1 = td(01jun2019) if id == 10
replace in_2 = td(01aug2019) if id == 10
replace out_2 = td(01jul2019) if id == 10
replace in_1 = td(01jan2010) if id == 11
replace out_1 = td(01jun2019) if id == 11
replace in_2 = td(01jun2019) if id == 11
replace out_1 = td(01jun2019) if id == 12
replace out_2 = td(01jun2019) if id == 12
replace in_1 = td(01jan2010) if id == 13
replace in_1 = td(01jan2018) if id == 14
format in_* out_* %td
save `mig_wide', replace

clear
input long id long event_date str3 event_type
2  . ""
3  . ""
4  . ""
5  . ""
6  . ""
7  . ""
8  . ""
9  . ""
10 . ""
11 . ""
12 . ""
13 . ""
14 . ""
end
drop if missing(event_date)
local row = _N
foreach spec in ///
    "2  01dec2017 Utv" ///
    "3  01dec2017 Utv" ///
    "3  01feb2018 Inv" ///
    "4  20feb2018 Inv" ///
    "5  02jan2017 Inv" ///
    "6  01jan2017 Inv" ///
    "7  01jun2019 Utv" ///
    "8  01jan2010 Inv" ///
    "8  01jun2019 Utv" ///
    "8  01aug2019 Inv" ///
    "9  01jan2010 Inv" ///
    "9  01jun2019 Utv" ///
    "9  01aug2019 Inv" ///
    "9  01may2021 Utv" ///
    "10 01jan2010 Inv" ///
    "10 01jun2019 Utv" ///
    "10 01jul2019 Utv" ///
    "10 01aug2019 Inv" ///
    "11 01jan2010 Inv" ///
    "11 01jun2019 Utv" ///
    "11 01jun2019 Inv" ///
    "12 01jun2019 Utv" ///
    "12 01jun2019 Utv" ///
    "13 01jan2010 Inv" ///
    "14 01jan2018 Inv" {
    gettoken sid rest : spec
    gettoken sdate stype : rest
    local ++row
    set obs `row'
    replace id = real("`sid'") in `row'
    replace event_date = td(`sdate') in `row'
    replace event_type = "`stype'" in `row'
}
format event_date %td
save `mig_long', replace

**# Wide-format exact validation

tempfile wide_excl wide_cens
use `master', clear
migrations, migfile("`mig_wide'") keepimmigrants minresidence(365) ///
    saveexclude("`wide_excl'") savecensor("`wide_cens'") replace
_check_complex_migrations "wide"

preserve
use `wide_excl', clear
sort id
local ok_excl = (_N == 4 & ///
    id[1] == 2 & exclude_reason[1] == "Emigrated before study start, never returned" & ///
    id[2] == 3 & exclude_reason[2] == "Abroad at baseline (emigrated before, returned after study start)" & ///
    id[3] == 5 & exclude_reason[3] == "Insufficient residence before study start (365 days required)" & ///
    id[4] == 14 & exclude_reason[4] == "Insufficient residence before study start (365 days required)")
restore
run_val "wide: saveexclude has exact excluded IDs and reasons" `ok_excl'

preserve
use `wide_cens', clear
sort id
local ok_cens = (_N == 4 & ///
    id[1] == 7 & migration_out_dt[1] == td(01jun2019) & ///
    id[2] == 9 & migration_out_dt[2] == td(01may2021) & ///
    id[3] == 11 & migration_out_dt[3] == td(01jun2019) & ///
    id[4] == 12 & migration_out_dt[4] == td(01jun2019))
restore
run_val "wide: savecensor has exact nonmissing censoring rows" `ok_cens'

**# Long-format exact validation

tempfile long_excl long_cens
use `master', clear
migrations, migfile("`mig_long'") keepimmigrants minresidence(365) ///
    saveexclude("`long_excl'") savecensor("`long_cens'") replace
_check_complex_migrations "long"

preserve
use `long_excl', clear
sort id
local ok_excl = (_N == 4 & ///
    id[1] == 2 & exclude_reason[1] == "Emigrated before study start, never returned" & ///
    id[2] == 3 & exclude_reason[2] == "Abroad at baseline (emigrated before, returned after study start)" & ///
    id[3] == 5 & exclude_reason[3] == "Insufficient residence before study start (365 days required)" & ///
    id[4] == 14 & exclude_reason[4] == "Insufficient residence before study start (365 days required)")
restore
run_val "long: saveexclude has exact excluded IDs and reasons" `ok_excl'

preserve
use `long_cens', clear
sort id
local ok_cens = (_N == 4 & ///
    id[1] == 7 & migration_out_dt[1] == td(01jun2019) & ///
    id[2] == 9 & migration_out_dt[2] == td(01may2021) & ///
    id[3] == 11 & migration_out_dt[3] == td(01jun2019) & ///
    id[4] == 12 & migration_out_dt[4] == td(01jun2019))
restore
run_val "long: savecensor has exact nonmissing censoring rows" `ok_cens'

**# Sort/order and data preservation contract

use `master', clear
gsort -id
gen long orig_order = _n
tempfile unsorted_master
save `unsorted_master', replace

use `unsorted_master', clear
migrations, migfile("`mig_wide'") keepimmigrants minresidence(365)
capture assert source_tag == "kept"
local ok_values = (_rc == 0)
run_val "wide: unrelated master variables are preserved for retained rows" `ok_values'

local ok_sort = 1
forvalues i = 1/`=_N-1' {
    if id[`i'] > id[`i' + 1] local ok_sort = 0
}
run_val "wide: final sort order is deterministic by id after merge" `ok_sort'

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
display "RESULT: validation_migrations_adversarial_boundaries tests=" ///
    scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)

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
